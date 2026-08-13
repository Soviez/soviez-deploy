#!/usr/bin/env bash
# Phase 20 — concurrency, lost-response recovery, grace/LG inject, stage warning vs blocked
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase20_fixture.sh
source "$ROOT/tests/helpers/phase20_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

pass_count=0
ok() { echo "OK: $1"; pass_count=$((pass_count + 1)); }

# --- lost response: commit, discard stdout, recover via get/idempotency ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-lost-$$"
soviez_migration_authorization_commit "$PAIR_ID" 1 >/dev/null
op_id="$(basename "$(find "$SOVIEZ_MIG_ROOT/ops" -mindepth 1 -maxdepth 1 -type d | head -1)")"
recovered="$(soviez_migration_authorization_recover "$op_id")"
assert_eq "$(soviez_json_get "$recovered" transaction_status)" "committed" "recover committed"
auth_id="$(soviez_json_get "$recovered" authorization_id)"
ledger_get="$(soviez_migration_p20_ledger get --account-id acct-p20 --idempotency-key "$SOVIEZ_MIG_P20_IDEMPOTENCY_KEY")"
assert_eq "$(soviez_json_get "$ledger_get" authorization_id)" "$auth_id" "ledger get matches"
ok "lost response recover via op + idempotency get"

# --- grace fail inject → recovery_required style, token still 0 ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_INJECT_GRACE_FAIL=1
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
snap="$(soviez_migration_p20_ledger snapshot --license-id lic-p20)"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "grace fail token still 0"
set +e
( set -e; soviez_migration_destination_activate "$PAIR_ID" ) >/dev/null 2>/tmp/p20-grace-fail.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_SOURCE_GRACE_APPLY_FAILED /tmp/p20-grace-fail.err
unset SOVIEZ_MIG_P20_INJECT_GRACE_FAIL
ok "grace fail inject token 0 recovery path"

# --- LG deny inject ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
export SOVIEZ_MIG_P20_INJECT_LG_DENY=1
set +e
( set -e; soviez_migration_destination_binding_apply "$auth_id" ) >/dev/null 2>/tmp/p20-lg-deny.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_LICENSE_GUARD_DENIED /tmp/p20-lg-deny.err
unset SOVIEZ_MIG_P20_INJECT_LG_DENY
ok "LG deny inject blocks binding"

# --- optional stage warning (non-mandatory expired stage) ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_STAGE_IDS="expired-opt-stage"
export SOVIEZ_MIG_P20_MANDATORY_STAGES=""
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
set +e
soviez_migration_stage_rebind_apply "$auth_id" >/tmp/p20-stage-warn.out 2>/tmp/p20-stage-warn.err
src=$?
set -e
[[ "$src" -eq 1 ]]
grep -q '"warning":true' /tmp/p20-stage-warn.out || grep -q warning /tmp/p20-stage-warn.out
export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
act="$(soviez_migration_destination_activate "$PAIR_ID")"
assert_eq "$(soviez_json_get "$act" stage_rebind)" "WARNING" "activate stage WARNING"
report="$(soviez_migration_phase21_readiness "$auth_id")"
status="$(soviez_json_get "$report" readiness_status)"
[[ "$status" == "PASS" || "$status" == "WARNING" ]]
ok "optional stage warning not blocking phase21"

# --- mandatory stage blocked ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_STAGE_IDS="expired-mandatory-stage"
export SOVIEZ_MIG_P20_MANDATORY_STAGES="expired-mandatory-stage"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
set +e
soviez_migration_stage_rebind_apply "$auth_id" >/tmp/p20-stage-block.out 2>/tmp/p20-stage-block.err
src=$?
set -e
[[ "$src" -eq 2 ]]
export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
act="$(soviez_migration_destination_activate "$PAIR_ID")"
assert_eq "$(soviez_json_get "$act" stage_rebind)" "BLOCKED" "activate stage BLOCKED"
report="$(soviez_migration_phase21_readiness "$auth_id")"
assert_eq "$(soviez_json_get "$report" readiness_status)" "BLOCKED" "phase21 BLOCKED mandatory stage"
ok "mandatory stage blocked"

# --- concurrent commit same key (integration-level) ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-int-conc-$$"
(
  soviez_migration_authorization_commit "$PAIR_ID" 1 >/tmp/p20-int-conc-a.out 2>/dev/null &
  soviez_migration_authorization_commit "$PAIR_ID" 1 >/tmp/p20-int-conc-b.out 2>/dev/null &
  wait
) || true
snap="$(soviez_migration_p20_ledger snapshot --license-id lic-p20)"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "int concurrent qty 0"
assert_eq "$(soviez_json_get "$snap" committed_authorizations)" "1" "int concurrent one auth"
ok "concurrent integration same idempotency key"

echo "test_phase20_concurrency_and_recovery: PASS ($pass_count checks)"
