#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp -d)"
dir="$(soviez_persist_record_baseline "$tmp")"
[[ -f "$dir/cron.txt" && -f "$dir/systemd.txt" && -f "$dir/ld_preload.txt" ]]
ld="$(cat "$dir/ld_preload.txt")"
[[ "$ld" == "ABSENT" || "$ld" == "EMPTY" || "$ld" == "UNEXPECTED" ]]
echo PASS
rm -rf "$tmp"
