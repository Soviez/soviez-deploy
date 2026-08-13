#!/usr/bin/env bash
# Phase 22 G3 — runtime suspension response-loss + no duplicate stop.
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
# Finalize without response-loss so routing/integrations exist
soviez_migration_source_license_finalize "$ARCHIVE_OP" >/dev/null

export SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS=1
set +e
out="$(soviez_migration_p22_runtime_suspend "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: expected runtime response loss"; exit 1; }
echo "$out" | grep -q MIGRATION_RUNTIME_SUSPEND_RESPONSE_LOSS

stop_committed="$(dirname "$(soviez_migration_p22_suspend_state_path "$SOURCE_ID")")/stop_committed"
[[ -f "$stop_committed" ]]
[[ "$(cat "$SOVIEZ_ROOT/p22_source/erp_runtime/status")" == "SUSPENDED" ]]

# Retry completes ack without destructive re-action / duplicate
unset SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS
export SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS=0
out2="$(soviez_migration_p22_runtime_suspend "$ARCHIVE_OP")"
sf="$(soviez_json_get "$out2" suspended)"
[[ "$sf" == "True" || "$sf" == "true" ]]
dup="$(soviez_json_get "$out2" duplicate_suspension)"
[[ "$dup" == "False" || "$dup" == "false" ]]

# Status query after response loss path
out3="$(soviez_migration_p22_runtime_suspend "$ARCHIVE_OP")"
sf3="$(soviez_json_get "$out3" suspended)"
[[ "$sf3" == "True" || "$sf3" == "true" ]]

# No Production reactivation
set +e
( set -e; soviez_migration_p22_assert_not_accidentally_started "$SOURCE_ID" ) >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]]

echo "test_phase22_runtime_suspend_response_loss: PASS"
