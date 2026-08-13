#!/usr/bin/env bash
# Phase 21 — E2E: cutover happy path banners, rollback within window, unsafe denial
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase21_fixture.sh
source "$ROOT/tests/helpers/phase21_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_CLI_YES=1

# --- plan ---
plan="$(soviez_migration_cutover_plan "$PAIR_ID")"
plan_id="$(soviez_json_get "$plan" plan_id)"
assert_eq "$(soviez_json_get "$plan" traffic_owner)" "source" "plan traffic_owner source"
assert_eq "$(soviez_json_get "$plan" production_dns_changed)" "False" "plan dns unchanged"
soviez_migration_cutover_plan_show "$plan_id" >/dev/null
echo "CUTOVER PLAN — signed intent (traffic_owner=source)"

# --- cutover start with certification banners ---
banner_out="$(mktemp "${TMPDIR:-/tmp}/p21-banner.XXXXXX")"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1 2>"$banner_out")"
for line in \
  "TRAFFIC OWNER — DESTINATION" \
  "PRODUCTION DNS — CHANGED" \
  "SOURCE — MAINTENANCE (BUSINESS WRITES DENIED)" \
  "ROLLBACK WINDOW — OPEN" \
  "PHASE 22 READINESS — REPORTED" \
  "NO SOURCE PURGE" \
  "NO SOURCE ARCHIVE" \
  "NO SAAS PAYLOAD RELAY" \
  "MIGRATION TOKEN — CONSUMED EXACTLY ONCE (PHASE 20)"; do
  assert_contains "$(cat "$banner_out")" "$line" "banner $line"
done
rm -f "$banner_out"

op_id="$(soviez_json_get "$result" operation_id)"
auth_id="$(soviez_json_get "$result" authorization_id)"
fqdn="$(soviez_json_get "$result" fqdn)"
prev_dns="$(soviez_json_get "$result" previous_dns_target)"

assert_eq "$(soviez_json_get "$result" current_state)" "cutover_complete" "cutover complete"
assert_eq "$(soviez_json_get "$result" traffic_owner)" "destination" "traffic owner destination"
assert_eq "$(soviez_json_get "$result" production_dns_changed)" "True" "production dns changed"
assert_eq "$(soviez_migration_p21_dns_snapshot "$fqdn")" "$SOVIEZ_MIG_P21_DEST_IP" "dns points to dest"
echo "TRAFFIC OWNER — DESTINATION"
echo "PRODUCTION DNS — CHANGED"
echo "ROLLBACK WINDOW — OPEN"

# --- rollback after commit within window (R1) ---
rb="$(soviez_migration_rollback_run "$PAIR_ID" "$op_id" "$auth_id" "$fqdn" "$prev_dns")"
assert_eq "$(soviez_json_get "$rb" tier)" "R1" "rollback tier R1"
assert_eq "$(soviez_json_get "$rb" traffic_owner)" "source" "rollback traffic source"
assert_eq "$(soviez_json_get "$rb" token_restored)" "False" "token never restored"
to="$(soviez_migration_traffic_owner_get "$auth_id")"
assert_eq "$(soviez_json_get "$to" traffic_owner)" "source" "traffic owner restored source"
echo "IMMEDIATE ROLLBACK — R1 within window"

# --- unsafe denial after meaningful writes ---
soviez_phase21_fixture_init "$ROOT"
result2="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op2="$(soviez_json_get "$result2" operation_id)"
auth2="$(soviez_json_get "$result2" authorization_id)"
export SOVIEZ_MIG_P21_MEANINGFUL_WRITES=1
set +e
( set -e; soviez_migration_rollback_run "$PAIR_ID" "$op2" "$auth2" prod.example.test unset ) >/dev/null 2>/tmp/p21-unsafe.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_ROLLBACK_NOT_SAFE /tmp/p21-unsafe.err
echo "IMMEDIATE ROLLBACK — DENIED (MIGRATION_ROLLBACK_NOT_SAFE)"
unset SOVIEZ_MIG_P21_MEANINGFUL_WRITES

echo "test_phase21_cutover_e2e: PASS"
