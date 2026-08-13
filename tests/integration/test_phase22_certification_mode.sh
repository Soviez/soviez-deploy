#!/usr/bin/env bash
# Phase 22 — certification-mode hard gates (fail closed on material skips / simulation).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase22_cert_env
soviez_phase22_assert_cert_gates

# Material skip must fail under certification
export SOVIEZ_PHASE22_SKIP_HOST_REBOOT=1
set +e
out="$(soviez_migration_p22_assert_cert_gates 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: skip host reboot should die"; exit 1; }
echo "$out" | grep -q MIGRATION_PHASE22_CERT_GATE
export SOVIEZ_PHASE22_SKIP_HOST_REBOOT=0

export SOVIEZ_PHASE22_ALLOW_REBOOT_SIM=1
set +e
out="$(soviez_migration_p22_assert_cert_gates 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: reboot sim should die"; exit 1; }
export SOVIEZ_PHASE22_ALLOW_REBOOT_SIM=0

export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=0
set +e
out="$(soviez_migration_p22_assert_cert_gates 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: fixture archive should die"; exit 1; }
export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=1

export SOVIEZ_PHASE22_SKIP_S3=1
set +e
out="$(soviez_migration_p22_assert_cert_gates 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: S3 skip should die"; exit 1; }
export SOVIEZ_PHASE22_SKIP_S3=0

soviez_phase22_assert_cert_gates
echo "test_phase22_certification_mode: PASS"
