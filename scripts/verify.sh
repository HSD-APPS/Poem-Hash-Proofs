#!/usr/bin/env bash
# Check that a poem file matches an entry and that its timestamps are valid.
# Usage: scripts/verify.sh <poem-file> <entry-id>
set -euo pipefail

file="${1:?usage: scripts/verify.sh <poem-file> <entry-id>}"
id="${2:?usage: scripts/verify.sh <poem-file> <entry-id>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/entries/$id"
certs="$root/certs/freetsa"

expected="$(sed -n 's/.*"sha256": "\([0-9a-f]*\)".*/\1/p' "$dir/entry.json")"
actual="$(sha256sum "$file" | cut -d' ' -f1)"
if [[ "$expected" != "$actual" ]]; then
  echo "MISMATCH: file sha256 $actual, entry $id records $expected" >&2
  exit 1
fi
echo "sha256 matches entry $id"

for tsr in "$dir"/*.tsr; do
  openssl ts -verify -data "$file" -in "$tsr" \
    -CAfile "$certs/cacert.pem" -untrusted "$certs/tsa.crt" >/dev/null 2>&1 \
    || { echo "FAILED: $(basename "$tsr")" >&2; exit 1; }
  time="$(openssl ts -reply -in "$tsr" -text 2>/dev/null | sed -n 's/^Time stamp: //p')"
  echo "OK: $(basename "$tsr") signed $time"
done
