# shellcheck shell=bash
# Phase 22 — Rollback Window Closure, Source Archive, License Finalization,
# Safe Retirement Readiness. Purge/delete/wipe remain permanently unauthorized.

SOVIEZ_MIG_OP_STABILIZATION=migration_stabilization_observe
SOVIEZ_MIG_OP_ROLLBACK_WINDOW_CLOSE=migration_rollback_window_close
SOVIEZ_MIG_OP_SOURCE_ARCHIVE_PLAN=migration_source_archive_plan
SOVIEZ_MIG_OP_SOURCE_ARCHIVE=migration_source_archive
SOVIEZ_MIG_OP_SOURCE_LICENSE_FINALIZE=migration_source_license_finalize
SOVIEZ_MIG_OP_SOURCE_RUNTIME_SUSPEND=migration_source_runtime_suspend
SOVIEZ_MIG_OP_RETIREMENT_STATUS=migration_source_retirement_status
SOVIEZ_MIG_OP_PHASE23_READINESS=migration_phase23_readiness

# Defaults applied at use-site (engine.sh) so fixtures can override AFTER
# sourcing dist/soviez.sh. Do not bind 86400 here at source time.
# Production default: SOVIEZ_MIG_P22_STABILIZATION_SECONDS=86400
# Production default: SOVIEZ_MIG_P22_OBSERVE_TICK_SECONDS=1
SOVIEZ_MIG_P22_PHASE23_TTL_SECONDS="${SOVIEZ_MIG_P22_PHASE23_TTL_SECONDS:-86400}"

SOVIEZ_MIGRATION_CODES+=(
  MIGRATION_PHASE21_READINESS_REQUIRED
  MIGRATION_PHASE21_READINESS_EXPIRED
  MIGRATION_PHASE21_READINESS_INVALID
  MIGRATION_PHASE21_READINESS_DRIFT_DETECTED
  MIGRATION_STABILIZATION_REQUIRED
  MIGRATION_STABILIZATION_INCOMPLETE
  MIGRATION_DESTINATION_HEALTH_UNSTABLE
  MIGRATION_ROLLBACK_WINDOW_STILL_REQUIRED
  MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED
  MIGRATION_ROLLBACK_WINDOW_CLOSE_DENIED
  MIGRATION_ACTIVE_INCIDENT_BLOCKS_ARCHIVE
  MIGRATION_SOURCE_ARCHIVE_PLAN_REQUIRED
  MIGRATION_SOURCE_ARCHIVE_PLAN_INVALID
  MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED
  MIGRATION_SOURCE_ARCHIVE_VERIFY_FAILED
  MIGRATION_SOURCE_ARCHIVE_RESTORE_TEST_FAILED
  MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED
  MIGRATION_DESTINATION_BACKUP_REQUIRED
  MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED
  MIGRATION_LICENSE_FINALIZE_RESPONSE_LOSS
  MIGRATION_LICENSE_COMMIT_STATUS_UNKNOWN
  MIGRATION_SOURCE_RUNTIME_SUSPEND_FAILED
  MIGRATION_RUNTIME_SUSPEND_RESPONSE_LOSS
  MIGRATION_SOURCE_RUNTIME_ALREADY_SUSPENDED
  MIGRATION_ROLLBACK_CLOSE_RESPONSE_LOSS
  MIGRATION_SOURCE_PUBLIC_ROUTE_STILL_ACTIVE
  MIGRATION_SOURCE_INTEGRATIONS_STILL_ACTIVE
  MIGRATION_SOURCE_CREDENTIAL_DISPOSITION_INCOMPLETE
  MIGRATION_SOURCE_CERTIFICATE_RETENTION_REQUIRED
  MIGRATION_DNS_ROLLBACK_SNAPSHOT_REQUIRED
  MIGRATION_STAGE_SOURCE_ARCHIVE_FAILED
  MIGRATION_RETENTION_HOLD_ACTIVE
  MIGRATION_LEGAL_HOLD_ACTIVE
  MIGRATION_PURGE_NOT_AUTHORIZED
  MIGRATION_SOURCE_DELETE_NOT_AUTHORIZED
  MIGRATION_SOURCE_DISK_WIPE_NOT_AUTHORIZED
  MIGRATION_BACKUP_DELETE_NOT_AUTHORIZED
  MIGRATION_CERTIFICATE_REVOKE_NOT_AUTHORIZED
  MIGRATION_HOST_TERMINATION_NOT_AUTHORIZED
  MIGRATION_RETIREMENT_NOT_READY
  MIGRATION_PHASE23_NOT_READY
  MIGRATION_MANUAL_INTERVENTION_REQUIRED
  MIGRATION_PHASE22_CANONICAL_REQUIRED
  MIGRATION_PHASE22_CERT_GATE
  MIGRATION_PHASE22_CERT_CLOCK_DENIED
  MIGRATION_PHASE22_CONFIRMATION_REQUIRED
  MIGRATION_DOCKER_PRUNE_NOT_AUTHORIZED
)

# Permanent destructive bans + canonical gate for mutating Phase 22 ops.
# When SOVIEZ_MIG_P22_MUTATING=0 (status/show), only purge/delete bans apply.
soviez_migration_assert_phase22_allowed() {
  local op_type="${1:-}"
  local mutating="${SOVIEZ_MIG_P22_MUTATING:-1}"

  # Always die on destructive product flags — never authorized in Phase 22.
  if [[ "${SOVIEZ_MIG_SOURCE_PURGE:-0}" == "1" || "${SOVIEZ_MIG_PURGE_SOURCE:-0}" == "1" || "${SOVIEZ_MIG_APPLY_SOURCE_PURGE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_PURGE_NOT_AUTHORIZED "Source purge not authorized in Phase 22"
  fi
  if [[ "${SOVIEZ_MIG_SOURCE_DELETE:-0}" == "1" || "${SOVIEZ_MIG_DELETE_SOURCE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_DELETE_NOT_AUTHORIZED "Source delete not authorized"
  fi
  if [[ "${SOVIEZ_MIG_DISK_WIPE:-0}" == "1" || "${SOVIEZ_MIG_WIPE_SOURCE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_DISK_WIPE_NOT_AUTHORIZED "Source disk wipe not authorized"
  fi
  if [[ "${SOVIEZ_MIG_BACKUP_DELETE:-0}" == "1" || "${SOVIEZ_MIG_DELETE_BACKUP:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_BACKUP_DELETE_NOT_AUTHORIZED "Backup delete not authorized in Phase 22"
  fi
  if [[ "${SOVIEZ_MIG_CERT_REVOKE:-0}" == "1" || "${SOVIEZ_MIG_REVOKE_CERT:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_CERTIFICATE_REVOKE_NOT_AUTHORIZED "Certificate revoke not authorized"
  fi
  if [[ "${SOVIEZ_MIG_HOST_TERMINATE:-0}" == "1" || "${SOVIEZ_MIG_TERMINATE_HOST:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_HOST_TERMINATION_NOT_AUTHORIZED "Host termination not authorized"
  fi
  if [[ "${SOVIEZ_MIG_DOCKER_PRUNE:-0}" == "1" || "${SOVIEZ_MIG_DOCKER_SYSTEM_PRUNE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DOCKER_PRUNE_NOT_AUTHORIZED "docker prune not authorized"
  fi
  if [[ "${SOVIEZ_MIG_SAAS_PAYLOAD_RELAY:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DATA_EGRESS_DENIED "SaaS payload relay forbidden"
  fi

  case "$op_type" in
    migration_stabilization_observe|migration_rollback_window_close| \
    migration_source_archive_plan|migration_source_archive| \
    migration_source_license_finalize|migration_source_runtime_suspend| \
    migration_source_retirement_status|migration_phase23_readiness| \
    migration_phase22_readiness|"")
      ;;
    *)
      soviez_migration_die MIGRATION_PHASE22_CANONICAL_REQUIRED "Unauthorized Phase 22 op: ${op_type:-missing}"
      ;;
  esac

  if [[ "$mutating" == "1" ]]; then
    [[ "${SOVIEZ_MIG_P22_CANONICAL:-0}" == "1" ]] || \
      soviez_migration_die MIGRATION_PHASE22_CANONICAL_REQUIRED "Phase 22 mutating op requires SOVIEZ_MIG_P22_CANONICAL=1"
  fi
  return 0
}
