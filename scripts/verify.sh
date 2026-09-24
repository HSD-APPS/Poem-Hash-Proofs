#!/usr/bin/env bash
# Check that a file matches an entry and that every signed timestamp in it is valid.
# Usage: scripts/verify.sh <file> <entry-id>
set -euo pipefail

file="${1:?usage: scripts/verify.sh <file> <entry-id>}"
id="${2:?usage: scripts/verify.sh <file> <entry-id>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/entries/$id"

expected="$(sed -n 's/.*"sha256": "\([0-9a-f]*\)".*/\1/p' "$dir/entry.json")"
actual="$(openssl dgst -sha256 -r "$file" | cut -d' ' -f1)"
if [[ "$expected" != "$actual" ]]; then
  echo "MISMATCH: file sha256 $actual, entry $id records $expected" >&2
  exit 1
fi
echo "sha256 matches entry $id"

for tsr in "$dir"/*.tsr; do
  name="$(basename "$tsr")"
  certs="$root/certs/${name%%-*}"
  if [[ -f "$certs/tsa.crt" ]]; then
    ok() { openssl ts -verify -data "$file" -in "$tsr" -CAfile "$certs/cacert.pem" -untrusted "$certs/tsa.crt"; }
  else
    ok() { openssl ts -verify -data "$file" -in "$tsr" -CAfile "$certs/cacert.pem"; }
  fi
  ok >/dev/null 2>&1 || { echo "FAILED: $name" >&2; exit 1; }
  time="$(openssl ts -reply -in "$tsr" -text 2>/dev/null | sed -n 's/^Time stamp: //p')"
  echo "OK: $name signed $time"
done
