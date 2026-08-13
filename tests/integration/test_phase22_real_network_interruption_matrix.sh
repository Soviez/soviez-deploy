#!/usr/bin/env bash
# Phase 22 G3 — aggregate network interruption matrix (upload/retrieve/lost-ack/response-loss).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=0

fail=0
run() {
  local t="$1"
  echo "==> matrix: $t"
  if bash "$ROOT/tests/integration/$t"; then
    echo "OK $t"
  else
    echo "FAIL $t" >&2
    fail=1
  fi
}

run test_phase22_archive_lost_ack.sh
run test_phase22_license_finalization_response_loss.sh
run test_phase22_runtime_suspend_response_loss.sh
run test_phase22_s3_interruption.sh
run test_phase22_sftp_interruption.sh

[[ "$fail" -eq 0 ]] || { echo "test_phase22_real_network_interruption_matrix: FAILED"; exit 1; }
echo "test_phase22_real_network_interruption_matrix: PASS"
