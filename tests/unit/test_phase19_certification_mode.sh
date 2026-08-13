#!/usr/bin/env bash
# Phase 19 — certification mode gate enforcement
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
SOVIEZ_ROOT="$(mktemp -d /tmp/soviez-p19-certmode.XXXXXX)"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init

export SOVIEZ_PHASE19_CERTIFICATION=1
soviez_phase19_apply_cert_defaults
[[ "${SOVIEZ_MIG_TRANSFER_LOCAL}" == "0" ]]
[[ "${SOVIEZ_MIG_FORCE_FIXTURE_DB}" == "0" ]]
[[ "${SOVIEZ_MIG_FREEZE_FIXTURE}" == "0" ]]

set +e
( SOVIEZ_MIG_TRANSFER_LOCAL=1 soviez_phase19_assert_cert_gates )
rc=$?
set -e
[[ "$rc" -ne 0 ]]

set +e
( SOVIEZ_MIG_TRANSFER_LOCAL=0 SOVIEZ_MIG_FORCE_FIXTURE_DB=1 soviez_phase19_assert_cert_gates )
rc=$?
set -e
[[ "$rc" -ne 0 ]]

set +e
( SOVIEZ_MIG_FORCE_FIXTURE_DB=0 SOVIEZ_MIG_FORCE_FIXTURE_ERP=1 soviez_phase19_assert_cert_gates )
rc=$?
set -e
[[ "$rc" -ne 0 ]]

set +e
( SOVIEZ_MIG_FORCE_FIXTURE_ERP=0 SOVIEZ_P19_SKIP_COLIMA_REBOOT=1 SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT=1 soviez_phase19_assert_cert_gates )
rc=$?
set -e
[[ "$rc" -ne 0 ]]

echo "test_phase19_certification_mode: PASS"
