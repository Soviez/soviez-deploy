#!/usr/bin/env bash
# Phase 19 — real application write-freeze enforcement
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_FREEZE_FIXTURE=0 SOVIEZ_MIG_FREEZE_WATCHDOG=0
export SOVIEZ_MIG_FREEZE_KEEP_GUARD=1
export SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS=5
SOVIEZ_ROOT="$(mktemp -d /tmp/soviez-p19-freeze.XXXXXX)"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

PAIR=pair-freeze; OP=op-freeze-$$
# Minimal pair object for production id lookup
mkdir -p "$(soviez_migration_pair_dir "$PAIR")"
printf '{"migration_pair_id":"%s","source_production_id":"prod-fz"}\n' "$PAIR" \
  > "$(soviez_migration_pair_dir "$PAIR")/object.json"

# Pre: start guard without marker
soviez_migration_freeze_guard_start "$PAIR" "$OP" "prod-fz" >/dev/null
before="$(soviez_migration_freeze_write_probe "$OP" POST)"
echo "$before" | grep -q '"http_code":200'

# Freeze
soviez_migration_freeze_start "$PAIR" "$OP" >/dev/null
[[ -f "$(soviez_migration_freeze_dir "$OP")/WRITE_FREEZE.active" ]]
during="$(soviez_migration_freeze_write_probe "$OP" POST)"
echo "$during" | grep -q '"http_code":503'
readok="$(soviez_migration_freeze_write_probe "$OP" GET)"
echo "$readok" | grep -q '"http_code":200'

# Timeout path with short watchdog
OP2=op-freeze-to-$$
export SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS=2
export SOVIEZ_MIG_FREEZE_WATCHDOG=1
soviez_migration_freeze_start "$PAIR" "$OP2" >/dev/null
sleep 4
# reconcile/timeout should have released
soviez_migration_freeze_reconcile "$PAIR" "$OP2" >/dev/null
released="$(soviez_json_get "$(cat "$(soviez_migration_freeze_state_path "$OP2")")" released)"
[[ "$released" == "true" || "$released" == "True" || -f "$(soviez_migration_freeze_dir "$OP2")/timed_out" ]]

# Abort release
soviez_migration_freeze_release "$PAIR" "$OP" "operator_abort" >/dev/null
[[ ! -f "$(soviez_migration_freeze_dir "$OP")/WRITE_FREEZE.active" ]]

# Process crash recovery: leave marker, reconcile
OP3=op-crash-$$
soviez_migration_freeze_start "$PAIR" "$OP3" >/dev/null
# Simulate crash: kill guard only, leave marker
soviez_migration_freeze_guard_stop "$OP3" || true
soviez_migration_freeze_reconcile "$PAIR" "$OP3" >/dev/null
rel3="$(soviez_json_get "$(cat "$(soviez_migration_freeze_state_path "$OP3")")" released)"
[[ "$rel3" == "true" || "$rel3" == "True" ]]

echo "test_phase19_real_write_freeze: PASS"
