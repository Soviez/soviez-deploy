#!/usr/bin/env bash
# Phase 22 — reboot/network simulation: unset env, re-source suspend state from disk
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase22_fixture.sh
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
soviez_migration_phase22_run "$CUTOVER_OP_ID" "$SOURCE_ID" >/dev/null

# Capture paths before "reboot"
mig_root="$SOVIEZ_MIG_ROOT"
source_id="$SOURCE_ID"
suspend_path="$(soviez_migration_p22_suspend_state_path "$source_id")"
[[ -f "$suspend_path" ]]

# Simulate reboot: clear in-memory/env markers (keep SOVIEZ_ROOT disk)
saved_root="$SOVIEZ_ROOT"
unset SOVIEZ_MIG_P22_CANONICAL SOVIEZ_MIG_P22_CUTOVER_ID SOVIEZ_CLI_CONFIRM_PHRASE \
  CUTOVER_OP_ID SOURCE_ID AUTH_ID 2>/dev/null || true

# Re-init paths from disk
export SOVIEZ_ROOT="$saved_root"
export SOVIEZ_TEST_MODE=1
soviez_migration_p22_paths_init
assert_eq "$SOVIEZ_MIG_ROOT" "$mig_root" "mig root restored"

# Suspend state survives
[[ -f "$SOVIEZ_MIG_ROOT/runtime_suspend/$source_id/state.json" ]]
sus="$(cat "$SOVIEZ_MIG_ROOT/runtime_suspend/$source_id/state.json")"
assert_eq "$(soviez_json_get "$sus" suspended)" "True" "suspend survives reboot"
assert_eq "$(soviez_json_get "$sus" survives_reboot)" "True" "survives_reboot flag"

# Accidental start still denied after reboot
set +e
( set -e; soviez_migration_p22_assert_not_accidentally_started "$source_id" ) >/dev/null 2>/tmp/p22-reboot.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
echo "REBOOT SIM — SUSPEND STATE PERSISTED"

echo "test_phase22_reboot_network: PASS"
