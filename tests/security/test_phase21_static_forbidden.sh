#!/usr/bin/env bash
# Phase 21 — static forbidden operations scan (cutover modules)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
fail=0

scan_dirs=(
  "$ROOT/src/migration/cutover"
  "$ROOT/src/migration/rollback"
  "$ROOT/src/migration/production_domain"
  "$ROOT/src/migration/final_cutover_sync"
  "$ROOT/src/migration/source_transition"
  "$ROOT/src/migration/destination_go_live"
  "$ROOT/src/migration/stage_cutover"
  "$ROOT/src/migration/phase22_readiness"
)

for pat in \
  'SOVIEZ_MIG_SAAS_PAYLOAD_RELAY=1' \
  'source_purge_apply\b' \
  'source_archive_apply\b' \
  'certbot[[:space:]]+revoke' \
  'openssl[[:space:]]+revoke' \
  'nsupdate' \
  'certbot[[:space:]]+.*--dns' \
  'server_name[[:space:]]+\*' \
  ; do
  if rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE 'forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|False|false|null|validate_no_wildcard|Wildcard|do_not|Phase 22|no purge|no archive' >/dev/null 2>&1; then
    echo "FAIL forbidden pattern: $pat"
    rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
      | grep -vE 'forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|False|false|null|validate_no_wildcard|Wildcard|do_not|Phase 22|no purge|no archive' || true
    fail=1
  fi
done

# Phase 21 cutover IS allowed via canonical engine — must exist
rg -n 'soviez_migration_cutover_start\b' "$ROOT/src/migration/cutover/engine.sh" >/dev/null || {
  echo "FAIL: canonical cutover engine missing"
  fail=1
}

rg -n 'soviez_migration_assert_phase21_cutover_allowed' "${scan_dirs[@]}" >/dev/null || {
  echo "FAIL: assert_phase21_cutover_allowed missing in Phase 21 modules"
  fail=1
}

# Second token consume must remain forbidden in cutover path (reads for revalidation OK)
if rg -n 'quantity_consumed|grant_remaining' "${scan_dirs[@]}" 2>/dev/null \
  | grep -vE 'not fully consumed|token_consumed|Phase 20|never restored|exactly-once|must show|revalidates|preflight|snapshot|Token ledger|grant_remaining\)"' \
  | grep -vE 'UPDATE grants|commit|ledger commit|quantity_consumed=' >/dev/null 2>&1; then
  echo "FAIL: cutover modules may mutate token ledger"
  rg -n 'quantity_consumed|grant_remaining' "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE 'not fully consumed|token_consumed|Phase 20|never restored|exactly-once|must show|revalidates|preflight|snapshot|Token ledger|grant_remaining\)"' \
    | grep -vE 'UPDATE grants|commit|ledger commit|quantity_consumed=' || true
  fail=1
fi

# Phase 22 archive/purge must not be implemented in Phase 21
for pat in 'archive_source\b' 'purge_source\b' 'phase22_archive\b'; do
  if rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE 'forbidden|never|False|false|archives_source|purges_source|not authorized|Phase 22 handoff' >/dev/null 2>&1; then
    echo "FAIL Phase 22 archive/purge implementation: $pat"
    fail=1
  fi
done

bash "$ROOT/build/assemble.sh" >/dev/null
ver="$(grep -m1 '^# version:' "$ROOT/dist/soviez.sh" | sed 's/^# version:[[:space:]]*//' | tr -d '[:space:]')"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/dist_version.sh"
if ! soviez_test_accept_dist_version "$ver"; then
  echo "FAIL: dist/soviez.sh version '$ver' (expected 0.21–0.24 / 0.24.6.x-platform-cli)"
  fail=1
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase21_static_forbidden: PASS"
