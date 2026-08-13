#!/usr/bin/env bash
# Phase 18 — static gate: no payload transfer / cutover authorization
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail=0
scan() {
  local pat="$1"
  if rg -n "$pat" "$ROOT/src/migration/domain" "$ROOT/src/migration/dns" \
      "$ROOT/src/migration/landing" "$ROOT/src/migration/tls" "$ROOT/src/migration/routing" \
      2>/dev/null | grep -v ':.*False' | grep -v 'allowed": False' | grep -v 'forbidden' | grep -v 'denied' | grep -v 'assert_no' | grep -v 'die MIGRATION' >/dev/null; then
    echo "FORBIDDEN: $pat" >&2
    fail=1
  fi
}

scan 'SOVIEZ_MIG_ALLOW_TRANSFER=1'
scan 'SOVIEZ_MIG_ALLOW_CUTOVER=1'
scan 'payload_transfer_allowed=true'
scan 'cutover_authorized=true'
scan 'data_transfer_started=true'
scan 'migration_token_consumed=true'

# Positive guards
grep -q 'MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED' "$ROOT/src/migration/common/codes.sh"
grep -q 'MIGRATION_CUTOVER_NOT_AUTHORIZED' "$ROOT/src/migration/common/codes.sh"
grep -q 'soviez_migration_assert_no_transfer' "$ROOT/src/migration/routing/readiness.sh"

[[ $fail -eq 0 ]] || exit 1
echo "PASS test_phase18_no_payload_transfer"
