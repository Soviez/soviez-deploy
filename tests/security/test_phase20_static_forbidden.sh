#!/usr/bin/env bash
# Phase 20 — static forbidden operations scan (authorization / token / rebind / activation / phase21)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
fail=0

scan_dirs=(
  "$ROOT/src/migration/authorization"
  "$ROOT/src/migration/token"
  "$ROOT/src/migration/rebind"
  "$ROOT/src/migration/activation"
  "$ROOT/src/migration/phase21_readiness"
)

for pat in \
  'nsupdate' \
  'certbot[[:space:]]+.*--dns' \
  'dns_cutover_apply\b' \
  'activate_production\b' \
  'cutover_enable\b' \
  'source_purge_apply\b' \
  'phase21_cutover\b' \
  'migration-phase21-cutover' \
  ; do
  if rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE 'forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|False|false|null|pre_cutover|Phase 20|Phase 21|no cutover' >/dev/null 2>&1; then
    echo "FAIL forbidden pattern: $pat"
    rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
      | grep -vE 'forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|False|false|null|pre_cutover|Phase 20|Phase 21|no cutover' || true
    fail=1
  fi
done

rg -n 'soviez_migration_assert_no_cutover_dns_purge' "${scan_dirs[@]}" >/dev/null || {
  echo "FAIL: assert_no_cutover_dns_purge missing in Phase 20 modules"
  fail=1
}

rg -n 'soviez_migration_assert_phase20_authorization_allowed' "${scan_dirs[@]}" >/dev/null || {
  echo "FAIL: assert_phase20_authorization_allowed missing in Phase 20 modules"
  fail=1
}

bash "$ROOT/build/assemble.sh" >/dev/null
ver="$(grep -m1 '^# version:' "$ROOT/dist/soviez.sh" | sed 's/^# version:[[:space:]]*//' | tr -d '[:space:]')"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/dist_version.sh"
if ! soviez_test_accept_dist_version "$ver"; then
  echo "FAIL: dist/soviez.sh version '$ver' (expected 0.21–0.24 / 0.24.6.x-platform-cli)"
  fail=1
fi

# Phase 21 cutover modules exist separately — Phase 20 scope must still forbid cutover
if ! rg -n 'soviez_migration_cutover_start\b' "$ROOT/src/migration/cutover/engine.sh" >/dev/null 2>&1; then
  echo "FAIL: Phase 21 cutover engine expected under src/migration/cutover/"
  fail=1
fi

# Phase 19 transfer path must still block cutover bypass flags
if ! rg -n 'soviez_migration_assert_no_cutover_or_token' \
  "$ROOT/src/migration/transfer" "$ROOT/src/migration/final_sync" >/dev/null 2>&1; then
  echo "FAIL: transfer/final_sync missing assert_no_cutover_or_token"
  fail=1
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase20_static_forbidden: PASS"
