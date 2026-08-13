# shellcheck shell=bash
# Phase 19 certification-mode gates (gap closure). Developer fixtures remain outside cert mode.

soviez_phase19_certification_enabled() {
  [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]
}

soviez_phase19_cert_die() {
  local code="$1" msg="$2"
  soviez_migration_die "${code}" "CERTIFICATION: ${msg}"
}

soviez_phase19_apply_cert_defaults() {
  if ! soviez_phase19_certification_enabled; then
    return 0
  fi
  export SOVIEZ_PHASE19_REQUIRE_REAL_MTLS="${SOVIEZ_PHASE19_REQUIRE_REAL_MTLS:-1}"
  export SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES="${SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES:-1}"
  export SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING="${SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING:-1}"
  export SOVIEZ_PHASE19_REQUIRE_REAL_STAGE="${SOVIEZ_PHASE19_REQUIRE_REAL_STAGE:-1}"
  export SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT="${SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT:-1}"
  export SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION="${SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION:-1}"
  export SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER="${SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER:-1}"
  export SOVIEZ_PHASE19_FORBID_FIXTURE_ERP="${SOVIEZ_PHASE19_FORBID_FIXTURE_ERP:-1}"
  export SOVIEZ_PHASE19_FORBID_FIXTURE_DB="${SOVIEZ_PHASE19_FORBID_FIXTURE_DB:-1}"
  # Force real paths
  unset SOVIEZ_MIG_TRANSFER_LOCAL || true
  export SOVIEZ_MIG_TRANSFER_LOCAL=0
  unset SOVIEZ_MIG_FORCE_FIXTURE_DB || true
  export SOVIEZ_MIG_FORCE_FIXTURE_DB=0
  unset SOVIEZ_MIG_FREEZE_FIXTURE || true
  export SOVIEZ_MIG_FREEZE_FIXTURE=0
  unset SOVIEZ_P19_SKIP_COLIMA_REBOOT || true
  export SOVIEZ_P19_SKIP_COLIMA_REBOOT=0
}

soviez_phase19_assert_cert_gates() {
  soviez_phase19_apply_cert_defaults
  if ! soviez_phase19_certification_enabled; then
    return 0
  fi
  if [[ "${SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_MTLS:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_TRANSFER_LOCAL:-0}" == "1" ]]; then
      soviez_phase19_cert_die MIGRATION_TRANSFER_CHANNEL_FAILED "local-copy transfer forbidden in certification mode"
    fi
  fi
  if [[ "${SOVIEZ_PHASE19_FORBID_FIXTURE_DB:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_FORCE_FIXTURE_DB:-0}" == "1" ]]; then
      soviez_phase19_cert_die MIGRATION_DATABASE_DUMP_FAILED "fixture database forbidden in certification mode"
    fi
  fi
  if [[ "${SOVIEZ_PHASE19_FORBID_FIXTURE_ERP:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_FORCE_FIXTURE_ERP:-0}" == "1" ]]; then
      soviez_phase19_cert_die MIGRATION_DESTINATION_STAGING_FAILED "fixture ERP forbidden in certification mode"
    fi
  fi
  if [[ "${SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_P19_SKIP_COLIMA_REBOOT:-0}" == "1" ]]; then
      soviez_phase19_cert_die MIGRATION_TRANSFER_RECOVERY_REQUIRED "host reboot skip forbidden in certification mode"
    fi
  fi
  if [[ "${SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_P19_SKIP_NETWORK_INTERRUPTION:-0}" == "1" ]]; then
      soviez_phase19_cert_die MIGRATION_TRANSFER_CHANNEL_FAILED "network interruption skip forbidden in certification mode"
    fi
  fi
}

soviez_phase19_assert_channel_real() {
  local op_id="$1"
  local mode
  if [[ "${SOVIEZ_PHASE19_REQUIRE_REAL_MTLS:-0}" != "1" ]] && ! soviez_phase19_certification_enabled; then
    return 0
  fi
  mode="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$op_id")" 2>/dev/null || echo '{}')" mode)"
  if [[ "$mode" != "mtls" ]]; then
    soviez_phase19_cert_die MIGRATION_TRANSFER_CHANNEL_FAILED "channel mode must be mtls (got: ${mode:-missing})"
  fi
}
