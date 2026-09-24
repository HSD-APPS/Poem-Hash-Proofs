# Poem Hash Proofs

A public, append-only register of fingerprints of my poems, recorded **before** the poems are published.

Each entry proves that a poem existed, word for word, at a specific moment, without revealing the poem. When a poem is later published, anyone can check it against its entry here.

## Why

Poems are easy to copy and easy to claim. This register lets me answer any dispute over a poem calmly, with evidence anyone can check independently, instead of arguing. It doesn't ask anyone to trust me, GitHub or dates written in git history.

## How it works

1. **Fingerprint.** The final text of the poem is saved as a file, and its SHA-256 and SHA-512 hashes are computed. A hash is a fixed-length fingerprint: changing even one letter of the poem produces a completely different hash, and the poem can't be recovered from it.
2. **Independent timestamp.** Only the hash (never the poem) is sent to [FreeTSA](https://freetsa.org), a public time-stamp authority that follows the RFC 3161 standard. FreeTSA returns a small file (`.tsr`), signed with its own key, that binds that hash to its clock time. Neither I nor anyone else can create or backdate that signature.
3. **Public record.** The hashes and FreeTSA's signed replies are committed to this public repository, so the registration is visible to everyone from the moment it's pushed.

When a poem is published, anyone can hash the published text, find the matching entry and check FreeTSA's signature. If all three match, that exact text existed at the time FreeTSA signed.

### What each layer proves

| Layer | Proves | Trust needed |
|---|---|---|
| FreeTSA signature (`.tsr`) | The hash existed at the signed time | FreeTSA's clock and signing key |
| This public repository | The registration was published openly, under my account | GitHub's record of when the commit became public |
| Commit dates in git history | Nothing by itself: they are set by the committer's computer | Not relied on |

The signed timestamp is the core proof. The public repository adds a visible, dated announcement tied to my identity.

## Layout

```
README.md            this file
REGISTRY.md          one row per registered poem
certs/freetsa/       FreeTSA's root and signing certificates
entries/<id>/        one folder per poem
  entry.json         id, status, SHA-256, SHA-512, timestamp details
  freetsa-sha256.tsq / .tsr   request and signed reply for the SHA-256 hash
  freetsa-sha512.tsq / .tsr   request and signed reply for the SHA-512 hash
scripts/stamp.sh     registers a new poem
scripts/verify.sh    checks a poem file against an entry
```

Entry ids are the registration date plus a sequence number (`2026-09-24-01`). They don't reveal titles or content.

## Rules

- **Append-only.** Entries are never edited or deleted, and history is never rewritten or force-pushed.
- **Poems are never stored here**, only their hashes and timestamps.
- **Revisions get a new entry.** A revised poem is registered again; earlier entries stay as proof of earlier versions.
- **Revealing.** When a poem is published, its entry's `status` becomes `revealed` and a note with the poem's public location is added next to it. The hashes and timestamps are not touched.

## Verify an entry

Requires `openssl` and `sha256sum` (standard on macOS and Linux).

```sh
scripts/verify.sh path/to/poem.txt 2026-09-24-01
```

Or by hand:

```sh
sha256sum poem.txt        # compare with "sha256" in entries/<id>/entry.json
openssl ts -verify -data poem.txt \
  -in entries/<id>/freetsa-sha256.tsr \
  -CAfile certs/freetsa/cacert.pem -untrusted certs/freetsa/tsa.crt
openssl ts -reply -in entries/<id>/freetsa-sha256.tsr -text   # shows the signed time
```

`Verification: OK` means FreeTSA signed that exact file's hash at the time shown. For extra assurance, download FreeTSA's certificates yourself from https://freetsa.org/files/ instead of using the copies in `certs/`.

## Register a new poem

```sh
scripts/stamp.sh path/to/poem.txt
git add -A && git commit -m "Register <id>" && git push
```

The poem file must be saved exactly as it will later be published (same text, same encoding), because the hash covers every byte.
