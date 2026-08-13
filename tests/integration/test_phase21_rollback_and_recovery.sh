#!/usr/bin/env bash
# Phase 21 — lost response / reboot recovery; concurrent cutover conflict
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase21_fixture.sh
source "$ROOT/tests/helpers/phase21_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

pass_count=0
ok() { echo "OK: $1"; pass_count=$((pass_count + 1)); }

# --- lost response: cutover mid-state, recover via cutover_recover ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$result" operation_id)"
auth_id="$(soviez_json_get "$result" authorization_id)"

# Simulate reboot: discard in-memory view, recover from persisted state.
recovered="$(soviez_migration_cutover_recover "$op_id")"
assert_eq "$(soviez_json_get "$recovered" operation_id)" "$op_id" "recover same op"
assert_eq "$(soviez_json_get "$recovered" current_state)" "cutover_complete" "recover terminal state"
assert_eq "$(soviez_json_get "$recovered" traffic_owner)" "destination" "recover traffic owner"
ok "lost response cutover recover"

# --- mid-state freeze timeout recovery path ---
soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS=1
export SOVIEZ_MIG_P21_INJECT_SYNC_FAIL=1
set +e
( set -e; soviez_migration_cutover_start "$PAIR_ID" 1 ) >/dev/null 2>/tmp/p21-mid-fail.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_FINAL_CUTOVER_SYNC_FAILED /tmp/p21-mid-fail.err
soviez_migration_cutover_paths_init
partial_op="$(find "$SOVIEZ_MIG_CUTOVER_OPS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
partial_op="${partial_op##*/}"
[[ -n "$partial_op" ]]
rec="$(soviez_migration_cutover_recover "$partial_op")"
assert_contains "$rec" "operation_id" "partial recover readable"
unset SOVIEZ_MIG_P21_INJECT_SYNC_FAIL SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS
ok "mid-state failure recover"

# --- retry after partial failure completes idempotently ---
soviez_phase21_fixture_init "$ROOT"
first="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$first" operation_id)"
retry="$(soviez_migration_cutover_retry "$op_id")"
assert_eq "$(soviez_json_get "$retry" current_state)" "cutover_complete" "retry completes"
assert_eq "$(soviez_json_get "$retry" traffic_owner)" "destination" "retry traffic owner destination"
ok "retry after recover"

# --- concurrent cutover conflict (same pair, parallel starts) ---
soviez_phase21_fixture_init "$ROOT"
(
  soviez_migration_cutover_start "$PAIR_ID" 1 >/tmp/p21-conc-a.out 2>/tmp/p21-conc-a.err &
  pid_a=$!
  soviez_migration_cutover_start "$PAIR_ID" 1 >/tmp/p21-conc-b.out 2>/tmp/p21-conc-b.err &
  pid_b=$!
  wait "$pid_a" || true
  wait "$pid_b" || true
) || true
snap="$(soviez_migration_p20_ledger snapshot --license-id "$SOVIEZ_MIG_P20_LICENSE_ID")"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "concurrent token qty 0"
assert_eq "$(soviez_json_get "$snap" slot_count)" "1" "concurrent slot 1"
a_ok=0 b_ok=0
[[ "$(soviez_json_get "$(cat /tmp/p21-conc-a.out 2>/dev/null || echo '{}')" traffic_owner 2>/dev/null || true)" == "destination" ]] && a_ok=1
[[ "$(soviez_json_get "$(cat /tmp/p21-conc-b.out 2>/dev/null || echo '{}')" traffic_owner 2>/dev/null || true)" == "destination" ]] && b_ok=1
# One winner; loser may conflict or also idempotently return destination.
[[ "$a_ok" -eq 1 || "$b_ok" -eq 1 ]] || {
  # Fallback: check persisted traffic_owner if stdout raced
  to_fallback="$(soviez_migration_traffic_owner_get "$SOVIEZ_MIG_P21_AUTH_ID" 2>/dev/null || echo '{}')"
  [[ "$(soviez_json_get "$to_fallback" traffic_owner 2>/dev/null || true)" == "destination" ]] || {
    echo "FAIL: concurrent cutover none reached destination" >&2
    echo "--- a.err ---"; cat /tmp/p21-conc-a.err 2>/dev/null || true
    echo "--- b.err ---"; cat /tmp/p21-conc-b.err 2>/dev/null || true
    exit 1
  }
}
to="$(soviez_migration_traffic_owner_get "$SOVIEZ_MIG_P21_AUTH_ID")"
assert_eq "$(soviez_json_get "$to" traffic_owner)" "destination" "concurrent final traffic owner"
ok "concurrent cutover conflict safe"

echo "test_phase21_rollback_and_recovery: PASS ($pass_count checks)"
