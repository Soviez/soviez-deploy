#!/usr/bin/env bash
# Phase 19 — no Production cutover / activation / DNS mutation (static)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
fail=0

for pat in \
  'nsupdate' \
  'certbot[[:space:]]+.*--dns' \
  'traffic_cutover_started.: True' \
  'destination_production_activated.: True' \
  'StrictHostKeyChecking=no' \
  ; do
  if rg -n --glob 'src/migration/**' -e "$pat" "$ROOT/src/migration" 2>/dev/null \
    | grep -vE 'forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|Phase 20|Phase 21' >/dev/null 2>&1; then
    echo "FAIL cutover/activation pattern: $pat"; fail=1
  fi
done

rg -n 'MIGRATION_CUTOVER_NOT_AUTHORIZED|assert_no_cutover_or_token' "$ROOT/src/migration" >/dev/null || {
  echo "FAIL: cutover gate missing"; fail=1
}

# No production activation / cutover helpers in Phase 19 transfer
if rg -n 'activate_production\b|cutover_dns\b|dns_cutover_apply\b' \
  "$ROOT/src/migration/transfer" "$ROOT/src/migration/staging" "$ROOT/src/migration/final_sync" 2>/dev/null \
  | grep -vE 'forbidden|forbids|must not|never|NOT_AUTHORIZED|False|false' >/dev/null 2>&1; then
  echo "FAIL: activation/cutover helper"; fail=1
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase19_no_cutover: PASS"
