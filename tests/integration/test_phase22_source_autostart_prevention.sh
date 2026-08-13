#!/usr/bin/env bash
# Phase 22 G2 — ordinary source auto-start cannot restore Production after archived state.
# When run alone: uses fixture + requires a prior or inline real reboot proof via disk state.
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
MARKER="$ROOT/.tmp/p22-autostart-marker-$$"
printf '%s\n' "$SOVIEZ_ROOT" > "$MARKER"

soviez_migration_phase22_run "$CUTOVER_OP_ID" "$SOURCE_ID" >/dev/null
ARCHIVE_OP="$(cat "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR/by_source/${SOURCE_ID}.id")"
printf '%s\n' "$ARCHIVE_OP" > "$SOVIEZ_ROOT/archive_op.txt"
printf '%s\n' "$SOURCE_ID" > "$SOVIEZ_ROOT/source_id.txt"

echo "Colima reboot before auto-start attempt..."
colima stop
colima start
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
for i in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "FAIL: docker after reboot"; exit 1; }

# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT
SOVIEZ_ROOT="$(cat "$MARKER")"
soviez_paths_init
soviez_migration_p22_paths_init
SOURCE_ID="$(cat "$SOVIEZ_ROOT/source_id.txt")"
ARCHIVE_OP="$(cat "$SOVIEZ_ROOT/archive_op.txt")"

lic="$(cat "$(soviez_migration_p22_finalization_dir "$ARCHIVE_OP")/license.json")"
assert_eq "$(soviez_json_get "$lic" source_license_state)" "migrated_source_archived" "archived license"
sus="$(cat "$(soviez_migration_p22_suspend_state_path "$SOURCE_ID")")"
sf="$(soviez_json_get "$sus" suspended)"
[[ "$sf" == "True" || "$sf" == "true" ]]

# Ordinary startup attempt must fail closed
set +e
( set -e; soviez_migration_p22_assert_not_accidentally_started "$SOURCE_ID" ) >/tmp/p22-autostart.err 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: Production start allowed"; cat /tmp/p22-autostart.err; exit 1; }
grep -q MIGRATION_SOURCE_RUNTIME_ALREADY_SUSPENDED /tmp/p22-autostart.err

# Recovery mode flag alone is the only allowed diagnostic path (still not Production)
export SOVIEZ_MIG_P22_RECOVERY_START=1
soviez_migration_p22_assert_not_accidentally_started "$SOURCE_ID"
# Marker must remain SUSPENDED (never RUNNING as Production)
[[ "$(cat "${SOVIEZ_MIG_P22_ERP_RUNTIME_MARKER:-$SOVIEZ_ROOT/p22_source/erp_runtime/status}")" == "SUSPENDED" ]] \
  || [[ "$(cat "$SOVIEZ_ROOT/p22_source/erp_runtime/status")" == "SUSPENDED" ]]

rm -f "$MARKER"
echo "test_phase22_source_autostart_prevention: PASS"
