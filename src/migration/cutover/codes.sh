# shellcheck shell=bash
# Phase 21 cutover operation types + scoped gates.
#
# Phase 21 replaces the blanket Phase 18/19/20 cutover deny with a narrow
# allowlist. SOVIEZ_MIG_ALLOW_CUTOVER alone remains a forbidden bypass
# (see authorization/codes.sh); the ONLY authorized path is the canonical
# cutover engine, which sets SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1 internally.

SOVIEZ_MIG_OP_CUTOVER_PLAN=migration_cutover_plan
SOVIEZ_MIG_OP_FINAL_CUTOVER_SYNC=migration_final_cutover_sync
SOVIEZ_MIG_OP_SOURCE_MAINTENANCE=migration_source_maintenance
SOVIEZ_MIG_OP_DEST_ROUTE_ACTIVATE=migration_destination_route_activate
SOVIEZ_MIG_OP_DNS_CUTOVER=migration_dns_cutover
SOVIEZ_MIG_OP_TLS_VALIDATE=migration_tls_validate
SOVIEZ_MIG_OP_TRAFFIC_OWNER_SWITCH=migration_traffic_owner_switch
SOVIEZ_MIG_OP_POST_CUTOVER_VALIDATE=migration_post_cutover_validate
SOVIEZ_MIG_OP_INTEGRATION_ACTIVATE=migration_integration_activate
SOVIEZ_MIG_OP_IMMEDIATE_ROLLBACK=migration_immediate_rollback
SOVIEZ_MIG_OP_STAGE_CUTOVER=migration_stage_cutover
SOVIEZ_MIG_OP_PHASE22_READINESS=migration_phase22_readiness

SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS="${SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS:-1800}"
SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS="${SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS:-900}"
SOVIEZ_MIG_P22_READINESS_TTL_SECONDS="${SOVIEZ_MIG_P22_READINESS_TTL_SECONDS:-86400}"

SOVIEZ_MIGRATION_CODES+=(
  MIGRATION_CUTOVER_PLAN_REQUIRED
  MIGRATION_CUTOVER_PLAN_INVALID
  MIGRATION_CUTOVER_PLAN_EXPIRED
  MIGRATION_CUTOVER_NOT_ALLOWED
  MIGRATION_CUTOVER_ALREADY_STARTED
  MIGRATION_CUTOVER_CONFIRMATION_REQUIRED
  MIGRATION_CUTOVER_DRIFT_DETECTED
  MIGRATION_CANONICAL_CUTOVER_REQUIRED
  MIGRATION_FINAL_CUTOVER_SYNC_FAILED
  MIGRATION_FINAL_CUTOVER_SYNC_TIMEOUT
  MIGRATION_SOURCE_MAINTENANCE_FAILED
  MIGRATION_DESTINATION_ROUTE_ACTIVATE_FAILED
  MIGRATION_DNS_CUTOVER_FAILED
  MIGRATION_DNS_CUTOVER_NOT_CONFIRMED
  MIGRATION_TLS_PRODUCTION_INVALID
  MIGRATION_TLS_PRODUCTION_EXPIRED
  MIGRATION_TRAFFIC_OWNER_SWITCH_FAILED
  MIGRATION_TRAFFIC_OWNER_ALREADY_DESTINATION
  MIGRATION_POST_CUTOVER_HEALTH_FAILED
  MIGRATION_SPLIT_BRAIN_CUTOVER_DETECTED
  MIGRATION_INTEGRATION_ACTIVATE_FAILED
  MIGRATION_INTEGRATION_BEFORE_HEALTH_DENIED
  MIGRATION_ROLLBACK_WINDOW_EXPIRED
  MIGRATION_ROLLBACK_NOT_SAFE
  MIGRATION_ROLLBACK_NOT_ELIGIBLE
  MIGRATION_STAGE_CUTOVER_BLOCKED
  MIGRATION_STAGE_CUTOVER_MANDATORY_FAILED
  MIGRATION_PHASE22_NOT_READY
  MIGRATION_PHASE22_ARCHIVE_FORBIDDEN
  MIGRATION_BROAD_DNS_FORBIDDEN
  MIGRATION_WILDCARD_ROUTE_FORBIDDEN
)

soviez_migration_p21_assert_canonical() {
  [[ "${SOVIEZ_MIG_P21_CANONICAL_CUTOVER:-0}" == "1" ]] || \
    soviez_migration_die MIGRATION_CANONICAL_CUTOVER_REQUIRED "Cutover step requires the canonical Phase 21 engine"
}

soviez_migration_assert_phase21_cutover_allowed() {
  local op_type="${1:-}"
  case "$op_type" in
    migration_cutover_plan|migration_final_cutover_sync|migration_source_maintenance| \
    migration_destination_route_activate|migration_dns_cutover|migration_tls_validate| \
    migration_traffic_owner_switch|migration_post_cutover_validate|migration_integration_activate| \
    migration_immediate_rollback|migration_stage_cutover|migration_phase22_readiness)
      ;;
    *)
      soviez_migration_die MIGRATION_CUTOVER_NOT_ALLOWED "Unauthorized Phase 21 op: ${op_type:-missing}"
      ;;
  esac
  # Permanent bans — never authorized by any Phase 21 flag combination.
  if [[ "${SOVIEZ_MIG_SOURCE_PURGE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_PURGE_NOT_AUTHORIZED "Source purge forbidden in Phase 21"
  fi
  if [[ "${SOVIEZ_MIG_SAAS_PAYLOAD_RELAY:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DATA_EGRESS_DENIED "SaaS payload relay forbidden"
  fi
  # Soften archive forbid when Phase 22 canonical engine is active.
  # Purge remains forever forbidden via soviez_migration_assert_phase22_allowed.
  if [[ "${SOVIEZ_MIG_SOURCE_ARCHIVE:-0}" == "1" && "${SOVIEZ_MIG_P22_CANONICAL:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_PHASE22_ARCHIVE_FORBIDDEN "Phase 22 archive/purge not authorized in Phase 21"
  fi
  if [[ "${SOVIEZ_MIG_BROAD_DNS:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_BROAD_DNS_FORBIDDEN "Broad/zone-wide DNS mutation forbidden; exact record only"
  fi
  if [[ "${SOVIEZ_MIG_P21_WILDCARD_ROUTE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_WILDCARD_ROUTE_FORBIDDEN "Wildcard route forbidden"
  fi
  # SOVIEZ_MIG_ALLOW_CUTOVER remains a forbidden bypass regardless of op — the
  # ONLY way it is tolerated is when the canonical engine itself set the
  # companion flag (mirrors Phase 20's ALLOW_TOKEN_CONSUME/CANONICAL_COMMIT
  # pattern). Ordinary Phase 21 ops never need to set SOVIEZ_MIG_ALLOW_CUTOVER
  # and remain callable across separate CLI invocations (retry/rollback/etc.).
  if [[ "${SOVIEZ_MIG_ALLOW_CUTOVER:-0}" == "1" && "${SOVIEZ_MIG_P21_CANONICAL_CUTOVER:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_CANONICAL_CUTOVER_REQUIRED "SOVIEZ_MIG_ALLOW_CUTOVER bypass forbidden; use canonical cutover engine"
  fi
  return 0
}
