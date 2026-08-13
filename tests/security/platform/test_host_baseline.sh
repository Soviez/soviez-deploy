#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp -d)"
dir="$(soviez_host_record_baseline "$tmp")"
[[ -f "$dir/uid0.txt" && -f "$dir/suid.txt" && -f "$dir/sgid.txt" && -f "$dir/caps.txt" ]]
echo PASS
rm -rf "$tmp"
