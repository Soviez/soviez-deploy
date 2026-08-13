#!/usr/bin/env bash
# Phase 22 G3 — License finalization response-loss + commit-status-unknown recovery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=0
export SOVIEZ_PHASE22_REQUIRE_REAL_S3=0
export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP=0

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
soviez_migration_rollback_window_close "$CUTOVER_OP_ID" >/dev/null
archive="$(soviez_migration_source_archive_start "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$archive" operation_id)"

export SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS=1
set +e
out="$(soviez_migration_p22_license_finalize "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: expected response loss"; exit 1; }
echo "$out" | grep -Eq 'MIGRATION_LICENSE_FINALIZE_RESPONSE_LOSS|MIGRATION_LICENSE_COMMIT_STATUS_UNKNOWN'

statef="$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.json"
ackf="$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.ack"
[[ -f "$statef" ]]
[[ ! -f "$ackf" ]]
assert_eq "$(soviez_json_get "$(cat "$statef")" source_license_state)" "migrated_source_archived" "committed before loss"
assert_eq "$(soviez_json_get "$(cat "$statef")" license_count)" "1" "one license"
assert_eq "$(soviez_json_get "$(cat "$statef")" token_consumed)" "1" "token once"

# Retry resolves commit-status-unknown without duplicate transition
unset SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS
export SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS=0
out2="$(soviez_migration_p22_license_finalize "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$out2" source_license_state)" "migrated_source_archived" "resolved"
assert_eq "$(soviez_json_get "$out2" duplicate_finalization)" "False" "no dup" || \
  [[ "$(soviez_json_get "$out2" duplicate_finalization)" == "false" ]]
[[ -f "$ackf" ]]

# Third call fully idempotent
out3="$(soviez_migration_p22_license_finalize "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$out3" license_count)" "1" "still one"

# Traffic owner unchanged
to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$AUTH_ID")" traffic_owner)"
assert_eq "$to" "destination" "traffic owner preserved"

echo "test_phase22_license_finalization_response_loss: PASS"
