#!/usr/bin/env bash
# Register a new poem: hash it, get FreeTSA (RFC 3161) timestamps, write an entry.
# Usage: scripts/stamp.sh <poem-file> [entry-id]
# The poem file itself is never copied into this repository; only its hashes are.
set -euo pipefail

file="${1:?usage: scripts/stamp.sh <poem-file> [entry-id]}"
root="$(cd "$(dirname "$0")/.." && pwd)"
tsa_url="https://freetsa.org/tsr"
certs="$root/certs/freetsa"

if [[ -n "${2:-}" ]]; then
  id="$2"
else
  day="$(date -u +%F)"
  n=1
  while [[ -d "$root/entries/$day-$(printf %02d "$n")" ]]; do n=$((n + 1)); done
  id="$day-$(printf %02d "$n")"
fi

dir="$root/entries/$id"
[[ -e "$dir" ]] && { echo "entry $id already exists; entries are never changed" >&2; exit 1; }
mkdir -p "$dir"

sha256="$(sha256sum "$file" | cut -d' ' -f1)"
sha512="$(sha512sum "$file" | cut -d' ' -f1)"

stamps=()
for algo in sha256 sha512; do
  openssl ts -query -data "$file" -no_nonce "-$algo" -cert -out "$dir/freetsa-$algo.tsq" 2>/dev/null
  curl -sS --fail -H "Content-Type: application/timestamp-query" \
    --data-binary @"$dir/freetsa-$algo.tsq" "$tsa_url" -o "$dir/freetsa-$algo.tsr"
  openssl ts -verify -data "$file" -in "$dir/freetsa-$algo.tsr" \
    -CAfile "$certs/cacert.pem" -untrusted "$certs/tsa.crt" >/dev/null 2>&1 \
    || { echo "FreeTSA reply for $algo failed verification" >&2; exit 1; }
  reply="$(openssl ts -reply -in "$dir/freetsa-$algo.tsr" -text 2>/dev/null)"
  time="$(sed -n 's/^Time stamp: //p' <<<"$reply")"
  serial="$(sed -n 's/^Serial number: //p' <<<"$reply")"
  iso="$(date -u -d "$time" +%Y-%m-%dT%H:%M:%SZ)"
  stamps+=("{\"authority\": \"FreeTSA\", \"imprint\": \"$algo\", \"time\": \"$iso\", \"serial\": \"$serial\", \"request\": \"freetsa-$algo.tsq\", \"reply\": \"freetsa-$algo.tsr\"}")
done

{
  printf '{\n  "id": "%s",\n  "status": "sealed",\n' "$id"
  printf '  "sha256": "%s",\n  "sha512": "%s",\n  "timestamps": [\n' "$sha256" "$sha512"
  printf '    %s,\n    %s\n  ]\n}\n' "${stamps[0]}" "${stamps[1]}"
} > "$dir/entry.json"

first_time="$(sed -n 's/.*"time": "\([^"]*\)".*/\1/p' "$dir/entry.json" | sort | head -1)"
printf '| [%s](entries/%s/) | %s | `%s` | sealed |\n' "$id" "$id" "$first_time" "$sha256" >> "$root/REGISTRY.md"

echo "registered $id"
echo "  sha256 $sha256"
echo "  first timestamp $first_time"
