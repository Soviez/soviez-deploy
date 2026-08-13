#!/usr/bin/env bash
# Phase 22 certification-mode shared env + gate assertion (G2/G3 closure).
# shellcheck shell=bash

soviez_phase22_cert_env() {
  export SOVIEZ_PHASE22_CERTIFICATION=1
  export SOVIEZ_PHASE22_REQUIRE_REAL_POSTGRES=1
  export SOVIEZ_PHASE22_REQUIRE_REAL_ARCHIVE_ENCRYPTION=1
  export SOVIEZ_PHASE22_REQUIRE_REAL_RESTORE_TEST=1
  export SOVIEZ_PHASE22_REQUIRE_REAL_S3=1
  export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP=1
  export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=1
  export SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION=1
  export SOVIEZ_PHASE22_FORBID_REBOOT_SIMULATION=1
  export SOVIEZ_PHASE22_FORBID_FIXTURE_ARCHIVE=1
  export SOVIEZ_PHASE22_FORBID_MATERIAL_SKIPS=1
  # Align fixture real-PG with cert gates.
  export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=1
  export SOVIEZ_MIG_P22_SKIP_HOST_REBOOT=0
  export SOVIEZ_PHASE22_SKIP_HOST_REBOOT=0
  export SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION=0
  export SOVIEZ_PHASE22_SKIP_S3=0
  export SOVIEZ_PHASE22_SKIP_SFTP=0
  export SOVIEZ_PHASE22_ALLOW_REBOOT_SIM=0
  export SOVIEZ_TEST_MODE=1
  export SOVIEZ_CLI_YES=1
  export SOVIEZ_MIG_ASSUME_YES=1
}

# Fail closed when material skips / simulation / fixture archive set under CERTIFICATION=1.
# Prefers assembled `soviez_migration_p22_assert_cert_gates` when dist is sourced.
soviez_phase22_assert_cert_gates() {
  if declare -F soviez_migration_p22_assert_cert_gates >/dev/null 2>&1; then
    soviez_migration_p22_assert_cert_gates
    return $?
  fi
  if [[ "${SOVIEZ_PHASE22_CERTIFICATION:-0}" != "1" ]]; then
    return 0
  fi
  if [[ "${SOVIEZ_PHASE22_FORBID_MATERIAL_SKIPS:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_PHASE22_SKIP_HOST_REBOOT:-0}" == "1" ]] \
       || [[ "${SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION:-0}" == "1" ]] \
       || [[ "${SOVIEZ_PHASE22_SKIP_S3:-0}" == "1" ]] \
       || [[ "${SOVIEZ_PHASE22_SKIP_SFTP:-0}" == "1" ]]; then
      echo "MIGRATION_PHASE22_CERT_GATE: material skip forbidden in certification" >&2
      return 1
    fi
  fi
  if [[ "${SOVIEZ_PHASE22_FORBID_REBOOT_SIMULATION:-1}" == "1" && "${SOVIEZ_PHASE22_ALLOW_REBOOT_SIM:-0}" == "1" ]]; then
    echo "MIGRATION_PHASE22_CERT_GATE: reboot simulation forbidden" >&2
    return 1
  fi
  if [[ "${SOVIEZ_PHASE22_FORBID_FIXTURE_ARCHIVE:-1}" == "1" && "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" != "1" ]]; then
    echo "MIGRATION_PHASE22_CERT_GATE: fixture archive forbidden" >&2
    return 1
  fi
  return 0
}
