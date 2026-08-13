# shellcheck shell=bash
# Phase 22 certification-mode hard gates. Fail closed on material skips.

soviez_migration_p22_cert_mode() {
  [[ "${SOVIEZ_PHASE22_CERTIFICATION:-0}" == "1" ]]
}

soviez_migration_p22_apply_cert_defaults() {
  soviez_migration_p22_cert_mode || return 0
  export SOVIEZ_PHASE22_REQUIRE_REAL_POSTGRES="${SOVIEZ_PHASE22_REQUIRE_REAL_POSTGRES:-1}"
  export SOVIEZ_PHASE22_REQUIRE_REAL_ARCHIVE_ENCRYPTION="${SOVIEZ_PHASE22_REQUIRE_REAL_ARCHIVE_ENCRYPTION:-1}"
  export SOVIEZ_PHASE22_REQUIRE_REAL_RESTORE_TEST="${SOVIEZ_PHASE22_REQUIRE_REAL_RESTORE_TEST:-1}"
  export SOVIEZ_PHASE22_REQUIRE_REAL_S3="${SOVIEZ_PHASE22_REQUIRE_REAL_S3:-1}"
  export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP="${SOVIEZ_PHASE22_REQUIRE_REAL_SFTP:-1}"
  export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT="${SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT:-1}"
  export SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION="${SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION:-1}"
  export SOVIEZ_PHASE22_FORBID_REBOOT_SIMULATION="${SOVIEZ_PHASE22_FORBID_REBOOT_SIMULATION:-1}"
  export SOVIEZ_PHASE22_FORBID_FIXTURE_ARCHIVE="${SOVIEZ_PHASE22_FORBID_FIXTURE_ARCHIVE:-1}"
  export SOVIEZ_PHASE22_FORBID_MATERIAL_SKIPS="${SOVIEZ_PHASE22_FORBID_MATERIAL_SKIPS:-1}"
  export SOVIEZ_MIG_P22_REQUIRE_REAL_PG="${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-1}"
  # Do NOT silently clear material skips — assert_cert_gates fails closed if they are set.
}

soviez_migration_p22_assert_cert_gates() {
  soviez_migration_p22_apply_cert_defaults
  soviez_migration_p22_cert_mode || return 0

  if [[ "${SOVIEZ_PHASE22_FORBID_FIXTURE_ARCHIVE:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE \
        "certification forbids fixture archive without SOVIEZ_MIG_P22_REQUIRE_REAL_PG=1"
    fi
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_REAL_POSTGRES:-1}" == "1" && "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "certification requires real postgres"
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_REAL_RESTORE_TEST:-1}" == "1" && "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "certification requires real restore test / real PG"
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_REAL_ARCHIVE_ENCRYPTION:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_BACKUP_DISABLE_ENCRYPTION:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE "certification requires real archive encryption"
    fi
  fi
  if [[ "${SOVIEZ_PHASE22_FORBID_REBOOT_SIMULATION:-1}" == "1" && "${SOVIEZ_PHASE22_ALLOW_REBOOT_SIM:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "certification forbids reboot simulation"
  fi
  if [[ "${SOVIEZ_PHASE22_FORBID_MATERIAL_SKIPS:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_PHASE22_SKIP_HOST_REBOOT:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material host reboot skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material network interruption skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE22_SKIP_S3:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material S3 skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE22_SKIP_SFTP:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material SFTP skip forbidden"
    fi
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT:-0}" == "1" && "${SOVIEZ_PHASE22_SKIP_HOST_REBOOT:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material host reboot skip forbidden"
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION:-0}" == "1" && "${SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material network interruption skip forbidden"
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_REAL_S3:-0}" == "1" && "${SOVIEZ_PHASE22_SKIP_S3:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material S3 skip forbidden"
  fi
  if [[ "${SOVIEZ_PHASE22_REQUIRE_REAL_SFTP:-0}" == "1" && "${SOVIEZ_PHASE22_SKIP_SFTP:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_CERT_GATE "material SFTP skip forbidden"
  fi
  if [[ "${SOVIEZ_MIG_SOURCE_PURGE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PURGE_NOT_AUTHORIZED "purge forbidden in certification"
  fi
  return 0
}

# Test-helper alias (matches phase19 naming).
soviez_phase22_assert_cert_gates() {
  soviez_migration_p22_assert_cert_gates
}
