#!/usr/bin/env bash
# Phase 19 — static gate: no SaaS payload relay
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
fail=0

# Forbidden SaaS / relay patterns in migration runtime
for pat in \
  'supabase' \
  'begin_license_migration' \
  'consume_ip_migration_token' \
  'migrate_license_ip' \
  'SOVIEZ_MIG_SAAS_PAYLOAD_RELAY=1' \
  's3://.*/migration' \
  'aws s3 cp' \
  ; do
  if rg -n --glob 'src/migration/**' -e "$pat" "$ROOT/src/migration" 2>/dev/null \
    | grep -vE 'forbidden|forbids|must not|never|Phase 20|assert_|DATA_EGRESS|NOT_AUTHORIZED|die MIGRATION' >/dev/null 2>&1; then
    echo "FAIL: SaaS/relay pattern: $pat"; fail=1
  fi
done

# Must have egress deny code / assert
rg -n 'MIGRATION_DATA_EGRESS_DENIED|assert_no_cutover_or_token' "$ROOT/src/migration" >/dev/null || {
  echo "FAIL: missing egress deny gate"; fail=1
}

# No curl|bash bootstrap in transfer path
if rg -n 'curl .*\|\s*bash' "$ROOT/src/migration" >/dev/null 2>&1; then
  echo "FAIL: curl|bash"; fail=1
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase19_no_saas_relay: PASS"
