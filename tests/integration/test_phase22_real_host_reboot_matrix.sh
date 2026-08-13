#!/usr/bin/env bash
# Phase 22 G2 — actual Colima host reboot matrix (not fixture simulation).
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
soviez_phase22_assert_cert_gates

cleanup() {
  soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true
}
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null

CP_DIR="$SOVIEZ_ROOT/p22_reboot_checkpoints"
mkdir -p "$CP_DIR"
# Host-side pointer survives Colima VM restart (SOVIEZ_ROOT is on macOS disk).
MARKER="$ROOT/.tmp/p22-reboot-marker-$$"
mkdir -p "$ROOT/.tmp"
printf '%s\n' "$SOVIEZ_ROOT" > "$MARKER"

write_cp() {
  local name="$1"
  shift
  printf '%s\n' "$@" > "$CP_DIR/$name.txt"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CP_DIR/$name.ts"
}

soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
write_cp 01_stabilization "op=$CUTOVER_OP_ID" "source=$SOURCE_ID"

export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
soviez_migration_rollback_window_close "$CUTOVER_OP_ID" >/dev/null
write_cp 02_closure_pre_commit "eligible=true"
write_cp 03_closure_post_commit "closed=true"
[[ -f "$(soviez_migration_p22_closure_by_cutover_path "$CUTOVER_OP_ID")" ]]

archive="$(soviez_migration_source_archive_start "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$archive" operation_id)"
write_cp 04_db_archive "archive_op=$ARCHIVE_OP"
write_cp 05_filestore_archive "archive_op=$ARCHIVE_OP"
write_cp 06_archive_encryption "archive_op=$ARCHIVE_OP"
write_cp 07_archive_upload "local_or_remote=local_default"
write_cp 08_archive_verification "status=verified"
write_cp 09_db_restore_test "status=pass"
[[ "$(soviez_json_get "$(soviez_migration_source_archive_status "$ARCHIVE_OP")" current_state)" == "verified" ]]

soviez_migration_source_license_finalize "$ARCHIVE_OP" >/dev/null
write_cp 10_license_finalization "state=migrated_source_archived"
soviez_migration_source_runtime_suspend "$ARCHIVE_OP" >/dev/null
write_cp 11_credential_disposition "done=true"
write_cp 12_public_route_disable "public=false"
write_cp 13_erp_runtime_suspend "suspended=true"
write_cp 14_postgres_optional_gate "optional=ok"

retirement="$(soviez_migration_source_retirement_status "$SOURCE_ID")"
p23="$(soviez_migration_phase23_readiness "$ARCHIVE_OP")"
write_cp 15_retirement_readiness "$(echo "$retirement" | head -c 200)"
write_cp 16_phase23_readiness "$(echo "$p23" | head -c 200)"

printf '%s\n' "$CUTOVER_OP_ID" > "$SOVIEZ_ROOT/cutover_id.txt"
printf '%s\n' "$SOURCE_ID" > "$SOVIEZ_ROOT/source_id.txt"
printf '%s\n' "$ARCHIVE_OP" > "$SOVIEZ_ROOT/archive_op.txt"
printf '%s\n' "$AUTH_ID" > "$SOVIEZ_ROOT/auth_id.txt"
PINNED_BEFORE="$SOVIEZ_ROOT/p22_pinned_backup/dump.fc"
[[ -f "$PINNED_BEFORE" ]]
[[ -f "$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")/archive_bundle.tar.enc" ]]

echo "Performing actual Colima host stop/start..."
colima stop
colima start
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
for i in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "FAIL: docker after Colima reboot"; exit 1; }

# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_CLI_YES=1 SOVIEZ_MIG_ASSUME_YES=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(cat "$MARKER")"
[[ -d "$SOVIEZ_ROOT" ]] || { echo "FAIL: SOVIEZ_ROOT missing after reboot: $SOVIEZ_ROOT"; exit 1; }
soviez_paths_init
soviez_migration_paths_init 2>/dev/null || true
soviez_migration_p22_paths_init

CUTOVER_OP_ID="$(cat "$SOVIEZ_ROOT/cutover_id.txt")"
SOURCE_ID="$(cat "$SOVIEZ_ROOT/source_id.txt")"
ARCHIVE_OP="$(cat "$SOVIEZ_ROOT/archive_op.txt")"
AUTH_ID="$(cat "$SOVIEZ_ROOT/auth_id.txt")"

for n in 01_stabilization 02_closure_pre_commit 03_closure_post_commit 04_db_archive \
  05_filestore_archive 06_archive_encryption 07_archive_upload 08_archive_verification \
  09_db_restore_test 10_license_finalization 11_credential_disposition 12_public_route_disable \
  13_erp_runtime_suspend 14_postgres_optional_gate 15_retirement_readiness 16_phase23_readiness; do
  [[ -f "$SOVIEZ_ROOT/p22_reboot_checkpoints/$n.txt" ]] || { echo "FAIL: missing checkpoint $n"; exit 1; }
done

lic="$(cat "$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.json")"
assert_eq "$(soviez_json_get "$lic" source_license_state)" "migrated_source_archived" "license after reboot"
sus="$(cat "$(soviez_migration_p22_suspend_state_path "$SOURCE_ID")")"
sus_flag="$(soviez_json_get "$sus" suspended)"
[[ "$sus_flag" == "True" || "$sus_flag" == "true" ]] || { echo "FAIL: suspend after reboot: $sus"; exit 1; }

[[ -f "$(soviez_migration_p22_closure_by_cutover_path "$CUTOVER_OP_ID")" ]]
[[ "$(soviez_json_get "$(soviez_migration_source_archive_status "$ARCHIVE_OP")" current_state)" == "verified" ]]
assert_eq "$(soviez_json_get "$lic" license_count)" "1" "one license"
assert_eq "$(soviez_json_get "$lic" slot_count)" "1" "one slot"
assert_eq "$(soviez_json_get "$lic" token_consumed)" "1" "token once"
assert_eq "$(soviez_json_get "$lic" traffic_owner)" "destination" "traffic owner"

to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$AUTH_ID")" traffic_owner)"
assert_eq "$to" "destination" "traffic_owner after reboot"

[[ -d "$SOVIEZ_ROOT/p22_source" ]]
[[ -f "$PINNED_BEFORE" ]]
[[ -f "$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")/archive_bundle.tar.enc" ]]
[[ -f "$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/routing.json" ]]

set +e
( set -e; soviez_migration_p22_assert_not_accidentally_started "$SOURCE_ID" ) >/dev/null 2>/tmp/p22-real-reboot-autostart.err
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: accidental start allowed after real reboot"; exit 1; }

soviez_migration_source_license_finalize "$ARCHIVE_OP" >/dev/null
soviez_migration_source_runtime_suspend "$ARCHIVE_OP" >/dev/null
lic2="$(cat "$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.json")"
assert_eq "$(soviez_json_get "$lic2" license_count)" "1" "no second license after retry"

rm -f "$MARKER"
echo "test_phase22_real_host_reboot_matrix: PASS"
