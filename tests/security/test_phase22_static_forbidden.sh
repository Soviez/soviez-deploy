#!/usr/bin/env bash
# Phase 22 — static forbidden operations scan
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"

scan_dirs=(
  "$ROOT/src/migration/stabilization"
  "$ROOT/src/migration/rollback_closure"
  "$ROOT/src/migration/source_archive"
  "$ROOT/src/migration/source_finalization"
  "$ROOT/src/migration/retirement"
  "$ROOT/src/migration/phase23_readiness"
  "$ROOT/src/migration/commands/stabilization.sh"
  "$ROOT/src/migration/commands/rollback_closure.sh"
  "$ROOT/src/migration/commands/archive.sh"
  "$ROOT/src/migration/commands/finalization.sh"
  "$ROOT/src/migration/commands/suspend.sh"
  "$ROOT/src/migration/commands/readiness.sh"
)

deny_filter='forbidden|forbids|must not|never|assert_|NOT_AUTHORIZED|die MIGRATION|False|false|null|do_not|no purge|not authorized|deny|Denied|DENIED|gate|BAN|ban'

for pat in \
  'docker[[:space:]]+system[[:space:]]+prune' \
  'docker[[:space:]]+prune' \
  '--purge-source' \
  'source_purge_apply' \
  'certbot[[:space:]]+revoke' \
  'openssl[[:space:]]+ca[[:space:]]+-revoke' \
  'host[[:space:]]+terminate' \
  'terminate_host' \
  'disk[[:space:]]+wipe' \
  ; do
  if rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE "$deny_filter" >/dev/null 2>&1; then
    echo "FAIL forbidden pattern: $pat"
    rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
      | grep -vE "$deny_filter" || true
    fail=1
  fi
done

if rg -n --glob '*.sh' -e 'rm[[:space:]]+-rf[[:space:]].*SOURCE|rm[[:space:]]+-rf[[:space:]].*filestore|rm[[:space:]]+-rf[[:space:]].*source_root' "${scan_dirs[@]}" 2>/dev/null \
  | grep -vE "$deny_filter|restore_test|work|plaintext|bundle" >/dev/null 2>&1; then
  echo "FAIL: destructive rm -rf of source data as product op"
  fail=1
fi

rg -n 'soviez_migration_assert_phase22_allowed' "${scan_dirs[@]}" >/dev/null || {
  echo "FAIL: assert_phase22_allowed missing"
  fail=1
}

# Must NOT implement later-phase purge apply inside Phase 22 modules
for pat in 'phase23_purge_apply' 'purge_source_apply' 'phase24_purge_apply'; do
  if rg -n --glob '*.sh' -e "$pat" "${scan_dirs[@]}" 2>/dev/null \
    | grep -vE "$deny_filter|implements_purge|implements_offline" >/dev/null 2>&1; then
    echo "FAIL unauthorized later-phase product implementation: $pat"
    fail=1
  fi
done

bash "$ROOT/build/assemble.sh" >/dev/null
ver="$(grep -m1 '^# version:' "$ROOT/dist/soviez.sh" | sed 's/^# version:[[:space:]]*//' | tr -d '[:space:]')"
if [[ "$ver" != "0.22.0-phase22" && "$ver" != "0.23.0-phase23" && "$ver" != "0.24.0-phase24" && "$ver" != "0.24.1-security-s1" && "$ver" != "0.24.2-security-s2" && "$ver" != "0.24.3-security-s3" && "$ver" != "0.24.4-security-s4" && "$ver" != "0.24.5-security-s5" && "$ver" != "0.24.5.1-security-s5-corr1" && "$ver" != "0.24.5.2-postcert-corr1" && "$ver" != "0.24.5.3-registry-gateway" ]]; then
  echo "FAIL: dist/soviez.sh version '$ver' (expected 0.22–0.24 phase installers)"
  fail=1
fi

bash -n "$ROOT/dist/soviez.sh" || { echo "FAIL: bash -n"; fail=1; }

[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase22_static_forbidden: PASS"
