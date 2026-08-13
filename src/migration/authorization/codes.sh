# shellcheck shell=bash
# Phase 20 authorization codes + scoped gates

SOVIEZ_MIG_OP_AUTH_PLAN=migration_authorization_plan
SOVIEZ_MIG_OP_AUTH_COMMIT=migration_authorization_commit
SOVIEZ_MIG_OP_DEST_ACTIVATION=migration_destination_activation
SOVIEZ_MIG_OP_SOURCE_GRACE=migration_source_grace_apply
SOVIEZ_MIG_OP_STAGE_REBIND=migration_stage_rebind
SOVIEZ_MIG_OP_P21_READINESS=migration_phase21_readiness
SOVIEZ_MIG_OP_AUTH_RECOVER=migration_authorization_recover
SOVIEZ_MIG_OP_PRE_CUTOVER_REVERSAL=migration_pre_cutover_reversal

SOVIEZ_MIG_P20_AUTH_TTL_SECONDS="${SOVIEZ_MIG_P20_AUTH_TTL_SECONDS:-1800}"
SOVIEZ_MIG_P21_READINESS_TTL_SECONDS="${SOVIEZ_MIG_P21_READINESS_TTL_SECONDS:-86400}"

SOVIEZ_MIGRATION_CODES+=(
  MIGRATION_PHASE19_READINESS_REQUIRED
  MIGRATION_PHASE19_READINESS_INVALID
  MIGRATION_PHASE19_DRIFT_DETECTED
  MIGRATION_TOKEN_REQUIRED
  MIGRATION_TOKEN_NOT_ELIGIBLE
  MIGRATION_TOKEN_EXPIRED
  MIGRATION_TOKEN_REVOKED
  MIGRATION_TOKEN_ALREADY_CONSUMED
  MIGRATION_TOKEN_QUANTITY_INSUFFICIENT
  MIGRATION_TOKEN_ACCOUNT_MISMATCH
  MIGRATION_TOKEN_LICENSE_MISMATCH
  MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT
  MIGRATION_TOKEN_LEDGER_INCONSISTENT
  MIGRATION_TOKEN_CONSUMED_EXACTLY_ONCE
  MIGRATION_AUTHORIZATION_REQUIRED
  MIGRATION_AUTHORIZATION_INVALID
  MIGRATION_AUTHORIZATION_EXPIRED
  MIGRATION_AUTHORIZATION_REPLAY_DENIED
  MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN
  MIGRATION_AUTHORIZATION_ALREADY_COMMITTED
  MIGRATION_LICENSE_LOCK_FAILED
  MIGRATION_LICENSE_BINDING_MISMATCH
  MIGRATION_SOURCE_BINDING_INVALID
  MIGRATION_DESTINATION_BINDING_INVALID
  MIGRATION_DUPLICATE_PRODUCTION_BINDING
  MIGRATION_DUPLICATE_SLOT_DETECTED
  MIGRATION_SOURCE_GRACE_APPLY_FAILED
  MIGRATION_SOURCE_GRACE_INVALID
  MIGRATION_DESTINATION_ACTIVATION_FAILED
  MIGRATION_LICENSE_GUARD_DENIED
  MIGRATION_STAGE_REBIND_FAILED
  MIGRATION_STAGE_REBIND_PARTIAL
  MIGRATION_SPLIT_BRAIN_DETECTED
  MIGRATION_LOCAL_APPLY_PENDING
  MIGRATION_COMPENSATION_REQUIRED
  MIGRATION_REVERSAL_NOT_AUTHORIZED
  MIGRATION_REVERSAL_SAFETY_CHECK_FAILED
  MIGRATION_PHASE21_NOT_READY
  MIGRATION_SOURCE_PURGE_NOT_AUTHORIZED
)

soviez_migration_assert_no_cutover_dns_purge() {
  # Phase 21 canonical cutover engine is the ONLY authorized path past this gate.
  # SOVIEZ_MIG_ALLOW_CUTOVER alone (env-flag bypass) remains permanently forbidden.
  if [[ "${SOVIEZ_MIG_ALLOW_CUTOVER:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_P21_CANONICAL_CUTOVER:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_CUTOVER_NOT_AUTHORIZED "Production cutover / DNS mutation not authorized in Phase 20 (use canonical Phase 21 cutover engine)"
    fi
  elif [[ "${SOVIEZ_MIG_DNS_CUTOVER:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_CUTOVER_NOT_AUTHORIZED "Production cutover / DNS mutation not authorized in Phase 20"
  fi
  if [[ "${SOVIEZ_MIG_SOURCE_PURGE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_PURGE_NOT_AUTHORIZED "Source purge not authorized"
  fi
  if [[ "${SOVIEZ_MIG_SAAS_PAYLOAD_RELAY:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DATA_EGRESS_DENIED "SaaS payload relay forbidden"
  fi
  return 0
}

soviez_migration_assert_phase20_authorization_allowed() {
  local op_type="${1:-}"
  case "$op_type" in
    migration_authorization_plan|migration_authorization_commit|migration_destination_activation|migration_source_grace_apply|migration_stage_rebind|migration_phase21_readiness|migration_authorization_recover|migration_pre_cutover_reversal)
      ;;
    *)
      soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "Unauthorized Phase 20 op: ${op_type:-missing}"
      ;;
  esac
  soviez_migration_assert_no_cutover_dns_purge
  # Still forbid disconnected generic burn
  if [[ "${SOVIEZ_MIG_ALLOW_TOKEN_CONSUME:-0}" == "1" && "${SOVIEZ_MIG_P20_CANONICAL_COMMIT:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_TOKEN_NOT_ELIGIBLE "Token consume only via canonical commit_migration_authorization"
  fi
  return 0
}
