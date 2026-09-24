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

### Proof methods

Every registration is backed by five independent methods:

| # | Method | What it records | Where |
|---|---|---|---|
| 1 | [FreeTSA](https://freetsa.org) RFC 3161 timestamp | Signed time of each hash | `entries/<id>/freetsa-*.tsr` |
| 2 | [DigiCert](https://www.digicert.com) RFC 3161 timestamp | Signed time of each hash | `entries/<id>/digicert-*.tsr` |
| 3 | [Sectigo](https://www.sectigo.com) RFC 3161 timestamp | Signed time of each hash | `entries/<id>/sectigo-*.tsr` |
| 4 | [Wayback Machine](https://web.archive.org/web/*/github.com/HSD-APPS/Poem-Hash-Proofs*) (Internet Archive) | Dated public copies of this repository's pages | [captures](https://web.archive.org/web/*/github.com/HSD-APPS/Poem-Hash-Proofs*) |
| 5 | [Software Heritage](https://archive.softwareheritage.org/browse/origin/?origin_url=https://github.com/HSD-APPS/Poem-Hash-Proofs) | Permanent archive of the full git history | [archive](https://archive.softwareheritage.org/browse/origin/?origin_url=https://github.com/HSD-APPS/Poem-Hash-Proofs) |

Software Heritage archived this repository on 2026-09-24 at 12:33 UTC, including entries `2026-09-24-01` to `2026-09-24-05`: snapshot `swh:1:snp:825b5e39501b22870da2346a3b256abf2ed0b805`, commit `swh:1:rev:3f6193bbd418ba05d420c75ef2d91b9e6b463cca`.

### Secrets

Some poems hide something (a name, a date) in their structure. The explanation of what is hidden and how to find it is kept in a separate file, and that file is registered as its own entry, with `"kind": "secret"` and `"of"` pointing to the poem's entry. It is sealed the same way: only its hash is public. Revealing the file later proves that the hidden layers were designed by the time of the timestamp, not discovered or invented afterwards.

### What each layer proves

| Layer | Proves | Trust needed |
|---|---|---|
| FreeTSA, DigiCert and Sectigo signatures (`.tsr`) | The hash existed at the signed time | Each authority's clock and signing key; they are independent of each other |
| This public repository | The registration was published openly, under my account | GitHub's record of when the commit became public |
| Wayback Machine and Software Heritage copies | The registration was public by the archive date, and survives even if GitHub or this repository disappears | Each archive's own records |
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

## Verify a poem (for an independent third party)

This is how anyone (a publisher, a judge, a competition jury, another poet) can check, without trusting the author, that a given poem existed at the registered time.

### What you need from the author

1. **The poem file itself**, exactly as it was registered: the original file, byte for byte (for example `poem.txt`). A copy retyped, pasted into a document, or re-saved with another editor will not match, because the hash covers every character, space, line break and encoding byte.
2. **The entry id** (for example `2026-09-24-03`). This is optional: the entry can also be found from the file's hash.
3. **Optionally, the secret file** of that poem, if the author wants to prove that hidden elements in the poem were designed by them. It has its own entry (`"kind": "secret"`, `"of": "<poem entry id>"`) and is checked the same way.

### What you take from public sources, not from the author

- **The signed timestamps** (`.tsr` files) and the recorded hashes: in this repository, under `entries/<id>/`.
- **The authorities' root certificates**, obtained yourself:
  - FreeTSA: https://freetsa.org/files/cacert.pem and https://freetsa.org/files/tsa.crt
  - DigiCert (DigiCert Trusted Root G4) and Sectigo (USERTrust RSA Certification Authority): already in the trust store of most operating systems (on Linux usually `/etc/ssl/certs/ca-certificates.crt`), or from https://www.digicert.com/kb/digicert-root-certificates.htm and https://www.sectigo.com/knowledge-base.
  - Copies are also in `certs/`, but using your own copies means you rely on nothing supplied by the author.
- **Tools**: `openssl`, `git`, `curl` (standard on macOS and Linux); `jq` is optional.

### Step by step

**Step 1. Get this repository.**

```sh
git clone https://github.com/HSD-APPS/Poem-Hash-Proofs
cd Poem-Hash-Proofs
```

**Step 2. Compute the hash of the file the author gave you.**

```sh
openssl dgst -sha256 poem.txt        # or: sha256sum poem.txt / shasum -a 256 poem.txt
```

The output is a 64-character fingerprint, for example `53dbf75aa41cc362fb78241c34e008339a39fadafd5ec44334b901d1fc1a1d52`.

**Step 3. Find that exact hash in the registry.**

```sh
grep <hash> REGISTRY.md
grep '"sha256"' entries/<id>/entry.json
```

The hash you computed must be identical, character for character, to the one in `REGISTRY.md` and in `entries/<id>/entry.json`. If it is not found, the file is not the registered one (or it was changed); stop here.

**Step 4. Check each authority's signed timestamp against the file.**

```sh
E=entries/<id>

# FreeTSA
curl -O https://freetsa.org/files/cacert.pem -O https://freetsa.org/files/tsa.crt
openssl ts -verify -data poem.txt -in $E/freetsa-sha256.tsr -CAfile cacert.pem -untrusted tsa.crt

# DigiCert and Sectigo (their replies carry their own certificate chain; only a trusted root is needed)
openssl ts -verify -data poem.txt -in $E/digicert-sha256.tsr -CAfile /etc/ssl/certs/ca-certificates.crt
openssl ts -verify -data poem.txt -in $E/sectigo-sha256.tsr  -CAfile /etc/ssl/certs/ca-certificates.crt
```

On macOS, use `-CAfile certs/digicert/cacert.pem` and `-CAfile certs/sectigo/cacert.pem`, after comparing them with the roots in Keychain Access, or export the system roots with `security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > roots.pem`.

Each command must print `Verification: OK`. This means the authority itself signed the hash of this exact file. Repeat with the `-sha512.tsr` files for a second, independent hash.

**Step 5. Read the signed time.**

```sh
openssl ts -reply -in $E/digicert-sha256.tsr -text
```

Look at three lines:

- `Time stamp:` the moment the authority signed, in UTC. This is the proof date.
- `Message data:` the hash the authority signed. It is the same 64-character hash you computed in step 2.
- `Serial number:` the authority's unique serial for this timestamp.

Do the same for the FreeTSA and Sectigo replies. The three times are from three independent organisations.

**Step 6. Check the public archives (optional, independent of GitHub).**

- Software Heritage: https://archive.softwareheritage.org/browse/origin/?origin_url=https://github.com/HSD-APPS/Poem-Hash-Proofs shows dated archive visits of this repository. Browse to `entries/<id>/entry.json` in a visit and confirm it records the same hash.
- Wayback Machine: https://web.archive.org/web/*/github.com/HSD-APPS/Poem-Hash-Proofs* lists dated captures of this repository's pages.

**Step 7. Conclude.**

If steps 2 to 5 pass, the file presented is, byte for byte, the one whose hash the authorities signed at the time shown. Nobody, including the author, can create or backdate those signatures. Anyone claiming the poem as theirs would need their own independently signed proof from an earlier time.

As a control, change a single character in a copy of the file and repeat steps 2 to 4: the hash is different, it is not in the registry, and every `openssl ts -verify` prints `Verification: FAILED` (`message imprint mismatch`).

### Shortcut

`scripts/verify.sh` runs steps 2 to 5 using the certificates in `certs/`:

```sh
scripts/verify.sh poem.txt <id>
```

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
