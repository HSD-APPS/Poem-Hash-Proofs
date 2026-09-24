# Poem Hash Proofs

A public, append-only register of fingerprints of my poems, recorded **before** the poems are published.

Each entry proves that a poem existed, word for word, at a specific moment, without revealing the poem. When a poem is later published, anyone can check it against its entry here.

## Why

Poems are easy to copy and easy to claim. This register lets me answer any dispute over a poem calmly, with evidence anyone can check independently, instead of arguing. It doesn't ask anyone to trust me, GitHub or dates written in git history.

## How it works

1. **Fingerprint.** The final text of the poem is saved as a file, and its SHA-256 and SHA-512 hashes are computed. A hash is a fixed-length fingerprint: changing even one letter of the poem produces a completely different hash, and the poem can't be recovered from it.
2. **Independent timestamps.** Only the hash (never the poem) is sent to three independent public time-stamp authorities that follow the RFC 3161 standard: [FreeTSA](https://freetsa.org), [DigiCert](https://www.digicert.com) and [Sectigo](https://www.sectigo.com). Each returns a small file (`.tsr`), signed with its own key, that binds the hash to its clock time. Neither I nor anyone else can create or backdate those signatures, and a claim would have to survive all three.
3. **Public record.** The hashes and the signed replies are committed to this public repository, so the registration is visible to everyone from the moment it's pushed.

When a poem is published, anyone can hash the published text, find the matching entry and check the signatures. If they match, that exact text existed at the time the authorities signed.

### Secrets

Some poems hide something (a name, a date) in their structure. The explanation of what is hidden and how to find it is kept in a separate file, and that file is registered as its own entry, with `"kind": "secret"` and `"of"` pointing to the poem's entry. It is sealed the same way: only its hash is public. Revealing the file later proves that the hidden layers were designed by the time of the timestamp, not discovered or invented afterwards.

### What each layer proves

| Layer | Proves | Trust needed |
|---|---|---|
| FreeTSA, DigiCert and Sectigo signatures (`.tsr`) | The hash existed at the signed time | Each authority's clock and signing key; they are independent of each other |
| This public repository | The registration was published openly, under my account | GitHub's record of when the commit became public |
| Commit dates in git history | Nothing by itself: they are set by the committer's computer | Not relied on |

The signed timestamps are the core proof. The public repository adds a visible, dated announcement tied to my identity.

## Layout

```
README.md            this file
REGISTRY.md          one row per registered poem or secret
certs/freetsa/       FreeTSA's root and signing certificates
certs/digicert/      DigiCert Trusted Root G4
certs/sectigo/       USERTrust RSA Certification Authority (Sectigo's root)
entries/<id>/        one folder per registered file
  entry.json         id, kind (poem or secret), status, SHA-256, SHA-512, timestamp details
  <authority>-sha256.tsq / .tsr   request and signed reply for the SHA-256 hash
  <authority>-sha512.tsq / .tsr   request and signed reply for the SHA-512 hash
scripts/stamp.sh     registers a new poem or secret, or adds timestamps to an entry
scripts/verify.sh    checks a file against an entry
```

Entry ids are the registration date plus a sequence number (`2026-09-24-01`). They don't reveal titles or content.

## Rules

- **Append-only.** An entry's hashes are never changed and entries are never deleted; history is never rewritten or force-pushed. The only additions to an existing entry are further independent timestamps of the same hashes and, on publication, its reveal note.
- **Poems are never stored here**, only their hashes and timestamps.
- **Revisions get a new entry.** A revised poem is registered again; earlier entries stay as proof of earlier versions.
- **Revealing.** When a poem is published, its entry's `status` becomes `revealed` and a note with the poem's public location is added next to it. The hashes and timestamps are not touched.

## Verify an entry

Requires `openssl` (standard on macOS and Linux). Registering also needs `curl` and `jq`.

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

# DigiCert and Sectigo replies carry their own certificate chain; only the root is needed
openssl ts -verify -data poem.txt -in entries/<id>/digicert-sha256.tsr -CAfile certs/digicert/cacert.pem
openssl ts -verify -data poem.txt -in entries/<id>/sectigo-sha256.tsr -CAfile certs/sectigo/cacert.pem
```

`Verification: OK` means the authority signed that exact file's hash at the time shown. For extra assurance, use root certificates you obtained yourself instead of the copies in `certs/`: FreeTSA's from https://freetsa.org/files/; DigiCert's and Sectigo's roots are also in the trust store of most operating systems.

## Register a new poem

```sh
scripts/stamp.sh path/to/poem.txt
git add -A && git commit -m "Register <id>" && git push
```

To register the secret of an already registered poem:

```sh
scripts/stamp.sh --secret-of <poem-entry-id> path/to/secret.html
```

The file must be saved exactly as it will later be published (same text, same encoding), because the hash covers every byte.
