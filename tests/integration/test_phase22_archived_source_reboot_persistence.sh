#!/usr/bin/env bash
# Phase 22 G2 — archived-source state persistence after actual Colima reboot.
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

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }
command -v colima >/dev/null 2>&1 || { echo "FAIL: Colima required"; exit 1; }

soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION=0
export SOVIEZ_PHASE22_REQUIRE_REAL_S3=0
export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP=0

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
MARKER="$ROOT/.tmp/p22-persist-marker-$$"
printf '%s\n' "$SOVIEZ_ROOT" > "$MARKER"

result="$(soviez_migration_phase22_run "$CUTOVER_OP_ID" "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$result" archive_operation_id)"
printf '%s\n' "$ARCHIVE_OP" > "$SOVIEZ_ROOT/archive_op.txt"
printf '%s\n' "$SOURCE_ID" > "$SOVIEZ_ROOT/source_id.txt"
printf '%s\n' "$AUTH_ID" > "$SOVIEZ_ROOT/auth_id.txt"
printf '%s\n' "$CUTOVER_OP_ID" > "$SOVIEZ_ROOT/cutover_id.txt"

echo "Colima reboot (archived-source persistence)..."
colima stop
colima start
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
for i in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "FAIL: docker after reboot"; exit 1; }

# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(cat "$MARKER")"
soviez_paths_init
soviez_migration_p22_paths_init
ARCHIVE_OP="$(cat "$SOVIEZ_ROOT/archive_op.txt")"
SOURCE_ID="$(cat "$SOVIEZ_ROOT/source_id.txt")"
AUTH_ID="$(cat "$SOVIEZ_ROOT/auth_id.txt")"
CUTOVER_OP_ID="$(cat "$SOVIEZ_ROOT/cutover_id.txt")"
[[ -n "$SOURCE_ID" && -n "$ARCHIVE_OP" ]] || { echo "FAIL: ids missing after reboot"; exit 1; }

lic="$(cat "$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.json")"
assert_eq "$(soviez_json_get "$lic" source_license_state)" "migrated_source_archived" "license"
sus="$(cat "$(soviez_migration_p22_suspend_state_path "$SOURCE_ID")")"
sf="$(soviez_json_get "$sus" suspended)"
[[ "$sf" == "True" || "$sf" == "true" ]]
assert_eq "$(soviez_json_get "$(soviez_migration_traffic_owner_get "$AUTH_ID")" traffic_owner)" "destination" "owner"
[[ -f "$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")/archive_bundle.tar.enc" ]]
[[ -d "$SOVIEZ_ROOT/p22_source" ]]
[[ -f "$SOVIEZ_ROOT/p22_pinned_backup/dump.fc" ]]
[[ "$(cat "$SOVIEZ_ROOT/p22_source/erp_runtime/status")" == "SUSPENDED" ]]

rm -f "$MARKER"
echo "test_phase22_archived_source_reboot_persistence: PASS"
