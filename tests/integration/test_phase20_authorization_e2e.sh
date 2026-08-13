#!/usr/bin/env bash
# Phase 20 — E2E: plan → commit/activate → grace → rebind → phase21 PASS
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase20_fixture.sh
source "$ROOT/tests/helpers/phase20_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_CLI_YES=1
export SOVIEZ_CLI_MIG_PAIR_ID="$PAIR_ID"

# --- plan ---
plan="$(soviez_migration_authorization_plan "$PAIR_ID")"
plan_id="$(soviez_json_get "$plan" plan_id)"
assert_eq "$(soviez_json_get "$plan" pair_id)" "$PAIR_ID" "plan pair_id"
assert_eq "$(soviez_json_get "$plan" phase21_allowed)" "False" "plan phase21 not allowed"
assert_file_exists "$(soviez_migration_p20_auth_dir "$plan_id")/plan.json"
echo "AUTHORIZATION PLAN — PASS"

# --- commit + activate (happy path) ---
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-e2e-$RANDOM"
export SOVIEZ_CLI_MIG_AUTH_ID=""
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
export SOVIEZ_CLI_MIG_AUTH_ID="$auth_id"

snap="$(soviez_migration_p20_ledger snapshot --license-id "$SOVIEZ_MIG_P20_LICENSE_ID")"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "post-commit token 0"
assert_eq "$(soviez_json_get "$snap" slot_count)" "1" "post-commit slot 1"
echo "MIGRATION TOKEN — CONSUMED (qty 0, slot 1)"

act="$(soviez_migration_destination_activate "$PAIR_ID")"
assert_eq "$(soviez_json_get "$act" destination_status)" "production_licensed_pre_cutover" "activation status"
assert_eq "$(soviez_json_get "$act" public_route)" "False" "activation public_route false"
assert_eq "$(soviez_json_get "$act" traffic_owner)" "source" "traffic owner source"
assert_eq "$(soviez_json_get "$act" production_dns_changed)" "False" "no dns change"
assert_eq "$(soviez_json_get "$act" traffic_cutover_started)" "False" "no cutover"
echo "DESTINATION ACTIVATION — production_licensed_pre_cutover"
echo "TRAFFIC CUTOVER — NOT STARTED"
echo "PRODUCTION DNS — NOT CHANGED"

# --- grace ---
grace="$(soviez_migration_source_grace_status "$SOVIEZ_MIG_P20_SOURCE_PROD")"
assert_contains "$grace" "migration_origin_grace" "grace applied"
echo "SOURCE GRACE — migration_origin_grace APPLIED"

# --- stage rebind ---
[[ -f "$SOVIEZ_MIG_ROOT/activation/$auth_id/stage_rebinds.json" ]]
stage_status="$(soviez_json_get "$act" stage_rebind)"
[[ "$stage_status" == "PASS" || "$stage_status" == "WARNING" ]]
echo "STAGE REBIND — ${stage_status}"

# --- phase21 readiness PASS ---
report="$(soviez_migration_phase21_readiness "$auth_id")"
assert_eq "$(soviez_json_get "$report" readiness_status)" "PASS" "phase21 PASS"
assert_eq "$(soviez_json_get "$report" token_consumed_count)" "1" "token consumed count"
assert_eq "$(soviez_json_get "$report" slot_count)" "1" "phase21 slot count"
assert_eq "$(soviez_json_get "$report" phase21_allowed)" "False" "phase21 not allowed yet"
echo "READY FOR PHASE 21 — PASS"

# --- idempotent retry activate/commit ---
retry_act="$(soviez_migration_destination_activate "$PAIR_ID")"
assert_eq "$(soviez_json_get "$retry_act" authorization_id)" "$auth_id" "retry activate same auth"
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-e2e-retry-$RANDOM"
set +e
( set -e; soviez_migration_authorization_commit "$PAIR_ID" 1 ) >/dev/null 2>/tmp/p20-e2e-retry.err
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: second commit should fail after token consumed (rc=$rc)" >&2; exit 1; }
echo "IDEMPOTENT RETRY — commit blocked (token already consumed, rc=$rc)"

# --- snapshot final proof ---
snap_final="$(soviez_migration_p20_ledger snapshot --license-id "$SOVIEZ_MIG_P20_LICENSE_ID")"
assert_eq "$(soviez_json_get "$snap_final" grant_remaining)" "0" "final token 0"
assert_eq "$(soviez_json_get "$snap_final" slot_count)" "1" "final slot 1"
assert_eq "$(soviez_json_get "$snap_final" committed_authorizations)" "1" "final one auth"
echo "LEDGER SNAPSHOT — token 0, slot 1, auth committed"

echo "test_phase20_authorization_e2e: PASS"
