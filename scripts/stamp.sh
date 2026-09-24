#!/usr/bin/env bash
# Register a file: hash it, get RFC 3161 timestamps from every authority below, write an entry.
#
# Usage:
#   scripts/stamp.sh <poem-file>                         register a new poem
#   scripts/stamp.sh --secret-of <entry-id> <file>       register the secret (key) of a registered poem
#   scripts/stamp.sh <file> <existing-entry-id>          add missing timestamps to an existing entry
#
# The file itself is never copied into this repository; only its hashes and signed timestamps are.
# An existing entry's hashes are never changed: the file must match them, and only new timestamps are added.
# Requires openssl, curl and jq.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# name|url   (certificates for each authority live in certs/<name>/)
authorities=(
  "freetsa|https://freetsa.org/tsr"
  "digicert|http://timestamp.digicert.com"
  "sectigo|http://timestamp.sectigo.com"
)
algos=(sha256 sha512)

usage() { sed -n '4,7p' "$0" >&2; exit 1; }

secret_of=""
if [[ "${1:-}" == "--secret-of" ]]; then
  [[ -n "${2:-}" ]] || usage
  secret_of="$2"
  shift 2
  [[ -f "$root/entries/$secret_of/entry.json" ]] || { echo "no entry $secret_of" >&2; exit 1; }
fi
file="${1:-}"
[[ -f "$file" ]] || usage

digest() { openssl dgst "-$1" -r "$2" | cut -d' ' -f1; }
sha256="$(digest sha256 "$file")"
sha512="$(digest sha512 "$file")"

new=1
if [[ -n "${2:-}" ]]; then
  id="$2"
  if [[ -e "$root/entries/$id" ]]; then
    new=0
    [[ -z "$secret_of" ]] || { echo "entry $id already exists" >&2; exit 1; }
    recorded="$(jq -r .sha256 "$root/entries/$id/entry.json")"
    [[ "$recorded" == "$sha256" ]] || { echo "file does not match entry $id (entry hashes are never changed)" >&2; exit 1; }
  fi
else
  day="$(date -u +%F)"
  n=1
  while [[ -d "$root/entries/$day-$(printf %02d "$n")" ]]; do n=$((n + 1)); done
  id="$day-$(printf %02d "$n")"
fi
dir="$root/entries/$id"
mkdir -p "$dir"

verify_reply() { # authority tsr
  local certs="$root/certs/$1"
  if [[ -f "$certs/tsa.crt" ]]; then
    openssl ts -verify -data "$file" -in "$2" -CAfile "$certs/cacert.pem" -untrusted "$certs/tsa.crt" >/dev/null 2>&1
  else
    openssl ts -verify -data "$file" -in "$2" -CAfile "$certs/cacert.pem" >/dev/null 2>&1
  fi
}

for a in "${authorities[@]}"; do
  name="${a%%|*}" url="${a#*|}"
  for algo in "${algos[@]}"; do
    tsq="$dir/$name-$algo.tsq" tsr="$dir/$name-$algo.tsr"
    [[ -f "$tsr" ]] && continue
    openssl ts -query -data "$file" -no_nonce "-$algo" -cert -out "$tsq" 2>/dev/null
    curl -sS --fail -H "Content-Type: application/timestamp-query" --data-binary @"$tsq" "$url" -o "$tsr"
    verify_reply "$name" "$tsr" || { rm -f "$tsq" "$tsr"; echo "$name reply for $algo failed verification" >&2; exit 1; }
    echo "stamped: $name $algo"
  done
done

# Rebuild the timestamp list from the signed replies on disk.
stamps="$(
  for a in "${authorities[@]}"; do
    name="${a%%|*}"
    for algo in "${algos[@]}"; do
      tsr="$dir/$name-$algo.tsr"
      [[ -f "$tsr" ]] || continue
      reply="$(openssl ts -reply -in "$tsr" -text 2>/dev/null)"
      time="$(sed -n 's/^Time stamp: //p' <<<"$reply" | sed 's/\.[0-9]*//')"
      serial="$(sed -n 's/^Serial number: //p' <<<"$reply")"
      jq -n --arg n "$name" --arg al "$algo" --arg t "$time" --arg s "$serial" '{
        authority: $n, imprint: $al,
        time: ($t | strptime("%b %d %H:%M:%S %Y GMT") | strftime("%Y-%m-%dT%H:%M:%SZ")),
        serial: $s, request: "\($n)-\($al).tsq", reply: "\($n)-\($al).tsr"}'
    done
  done | jq -s .
)"

if (( new )); then
  if [[ -n "$secret_of" ]]; then
    meta="$(jq -n --arg id "$id" --arg of "$secret_of" '{id: $id, kind: "secret", of: $of,
      note: "The poem’s secret: the key to what is hidden in the poem of entry \($of)."}')"
  else
    meta="$(jq -n --arg id "$id" '{id: $id, kind: "poem"}')"
  fi
  meta="$(jq --arg a "$sha256" --arg b "$sha512" '. + {status: "sealed", sha256: $a, sha512: $b}' <<<"$meta")"
else
  meta="$(jq '{id, kind: (.kind // "poem")} + . | del(.timestamps)' "$dir/entry.json")"
fi
jq --argjson ts "$stamps" '. + {timestamps: $ts}' <<<"$meta" > "$dir/entry.json"

if (( new )); then
  first="$(jq -r '[.timestamps[].time] | min' "$dir/entry.json")"
  what="poem"
  [[ -n "$secret_of" ]] && what="secret of [$secret_of](entries/$secret_of/)"
  printf '| [%s](entries/%s/) | %s | %s | `%s` | sealed |\n' "$id" "$id" "$what" "$first" "$sha256" >> "$root/REGISTRY.md"
  echo "registered $id"
else
  echo "updated $id"
fi
echo "  sha256 $sha256"
