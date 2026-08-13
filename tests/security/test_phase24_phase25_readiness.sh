#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
export SOVIEZ_SH_ROOT="$ROOT"
# shellcheck source=/dev/null
source dist/soviez.sh

out="$(soviez_security_phase25_readiness)"
printf '%s\n' "$out" | grep -q 'READY FOR PHASE 25'
printf '%s\n' "$out" | grep -q 'UNAUTHORIZED'
printf '%s\n' "$out" | grep -Eq 'PASS|WARNING|BLOCKED'
printf '%s\n' "$out" | grep -q 'ttl_hours=24'
printf '%s\n' "$out" | grep -q 'artifact_sha256='
printf '%s\n' "$out" | grep -q 'invalidate_on='

echo "OK test_phase24_phase25_readiness"
exit 0
