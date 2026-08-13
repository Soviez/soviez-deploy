#!/usr/bin/env bash
# Phase 22 — stabilization + rollback window closure
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase22_fixture.sh
source "$ROOT/tests/helpers/phase22_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

# Stabilization does not archive DB; skip real PG startup cost.
export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=0
soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null

# Instantaneous insufficient: duration 10 with cert clock advance across multiple ticks
stab="$(soviez_migration_stabilization_status "$CUTOVER_OP_ID")"
assert_eq "$(soviez_json_get "$stab" stabilization_status)" "PASS" "stabilization PASS"
assert_eq "$(soviez_json_get "$stab" clock_source)" "certification_override" "clock source"
sc="$(soviez_json_get "$stab" sample_count)"
[[ "$sc" -ge 2 ]] || { echo "FAIL: expected multiple observation ticks, got sample_count=$sc" >&2; exit 1; }
echo "STABILIZATION — PASS (cert clock multi-tick span, samples=$sc)"

# Injection failure
export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=0
soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
export SOVIEZ_MIG_P22_INJECT_HTTP_FAIL=1
set +e
( set -e; soviez_migration_stabilization_status "$CUTOVER_OP_ID" ) >/dev/null 2>/tmp/p22-stab-fail.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_DESTINATION_HEALTH_UNSTABLE /tmp/p22-stab-fail.err
unset SOVIEZ_MIG_P22_INJECT_HTTP_FAIL
echo "STABILIZATION — FAIL on inject"

# Fresh cutover for closure
export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=0
soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
plan="$(soviez_migration_rollback_window_close_plan "$CUTOVER_OP_ID")"
assert_eq "$(soviez_json_get "$plan" eligible)" "True" "close plan eligible"
close1="$(soviez_migration_rollback_window_close "$CUTOVER_OP_ID")"
assert_eq "$(soviez_json_get "$close1" automatic_rollback_allowed)" "False" "auto rollback false"
close2="$(soviez_migration_rollback_window_close "$CUTOVER_OP_ID")"
assert_eq "$(soviez_json_get "$close2" operation_id)" "$(soviez_json_get "$close1" operation_id)" "idempotent receipt"
echo "ROLLBACK WINDOW — CLOSED (idempotent)"

# Rollback eligibility after close
set +e
elig="$(soviez_migration_rollback_eligibility "$CUTOVER_OP_ID" "$AUTH_ID")"
erc=$?
set -e
[[ "$erc" -ne 0 ]]
assert_eq "$(soviez_json_get "$elig" code)" "MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED" "rollback not eligible after close"
echo "ROLLBACK — NOT ELIGIBLE AFTER CLOSE"

echo "test_phase22_stabilization_closure: PASS"
