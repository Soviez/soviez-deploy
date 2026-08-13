# shellcheck shell=bash

soviez_cmd_migration_discover() {
  local target="${SOVIEZ_CLI_MIG_TARGET:-${SOVIEZ_CLI_TARGET:-}}"
  soviez_migration_discover_run "$target"
}

soviez_cmd_migration_discovery_show() {
  soviez_migration_discovery_show "${SOVIEZ_CLI_MIG_DISCOVERY_ID:-}"
}

soviez_cmd_migration_bootstrap_destination() {
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_migration_bootstrap_run "$confirm"
}

soviez_cmd_migration_bootstrap_status() {
  soviez_migration_bootstrap_status "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_bootstrap_export() {
  soviez_migration_offline_export bootstrap "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_BOOTSTRAP_ID:-}}" "${SOVIEZ_CLI_MIG_OUTPUT:-}"
}

soviez_cmd_migration_bootstrap_import() {
  soviez_migration_offline_import "${SOVIEZ_CLI_MIG_IMPORT_PATH:-}"
}

soviez_cmd_migration_pair() {
  soviez_migration_pair_run \
    "${SOVIEZ_CLI_MIG_TARGET:-}" \
    "${SOVIEZ_CLI_MIG_DEST_CODE:-}" \
    "${SOVIEZ_CLI_MIG_CONFIRM_SRC_FP:-}" \
    "${SOVIEZ_CLI_MIG_CONFIRM_DST_FP:-}" \
    "${SOVIEZ_CLI_MIG_CONFIRM_LICENSE:-}" \
    "${SOVIEZ_CLI_MIG_CONFIRM_PROD:-}" \
    "${SOVIEZ_CLI_MIG_CONFIRM_BOOT:-}" \
    "${SOVIEZ_CLI_CONFIRM:-0}"
}

soviez_cmd_migration_pair_status() {
  soviez_migration_pair_status "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_pair_export() {
  soviez_migration_offline_export pair "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_OUTPUT:-}"
}

soviez_cmd_migration_pair_import() {
  soviez_migration_offline_import "${SOVIEZ_CLI_MIG_IMPORT_PATH:-}"
}

soviez_cmd_migration_readiness() {
  soviez_migration_readiness_run "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_readiness_show() {
  soviez_migration_readiness_show "${SOVIEZ_CLI_MIG_REPORT_ID:-}"
}

soviez_cmd_migration_readiness_export() {
  soviez_migration_offline_export readiness "${SOVIEZ_CLI_MIG_REPORT_ID:-}" "${SOVIEZ_CLI_MIG_OUTPUT:-}"
}

soviez_cmd_migration_readiness_import() {
  soviez_migration_offline_import "${SOVIEZ_CLI_MIG_IMPORT_PATH:-}"
}

soviez_cmd_migration_stage_select() {
  soviez_migration_stage_select "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_STAGE_ID:-}" select
}

soviez_cmd_migration_stage_unselect() {
  soviez_migration_stage_select "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_STAGE_ID:-}" unselect
}

soviez_cmd_migration_abort() {
  soviez_migration_abort_run "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_status() {
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  soviez_migration_paths_init
  local sf="$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  [[ -f "$sf" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown operation"
  cat "$sf"
}

soviez_cmd_migration_reattach() {
  soviez_cmd_migration_status
}

soviez_cmd_migration_cancel() {
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  soviez_migration_paths_init
  local sf="$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  [[ -f "$sf" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown operation"
  SOVIEZ_P="$sf" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["current_state"]="canceled"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps(d, separators=(",", ":")))
PY
}

soviez_cmd_migration_retry() {
  printf '{"status":"retry_not_applicable_phase17_idempotent_rerun"}\n'
}

soviez_cmd_migration_recover() {
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  soviez_migration_paths_init
  local sf="$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  if [[ ! -f "$sf" ]]; then
    soviez_migration_die MIGRATION_RECOVERY_REQUIRED "Operation state missing"
  fi
  cat "$sf"
}

soviez_cmd_migration_domain_plan() {
  soviez_migration_domain_plan_run "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_domain_plan_show() {
  soviez_migration_domain_plan_show "${SOVIEZ_CLI_MIG_PLAN_ID:-}"
}

soviez_cmd_migration_dns_challenge_create() {
  soviez_migration_dns_challenge_create "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_PLAN_ID:-}"
}

soviez_cmd_migration_dns_challenge_verify() {
  soviez_migration_dns_challenge_verify "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}"
}

soviez_cmd_migration_dns_challenge_abort() {
  soviez_migration_dns_challenge_abort "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}"
}

soviez_cmd_migration_dns_challenge_retry() {
  # Renew: new challenge id for expired/superseded challenges.
  soviez_migration_dns_challenge_renew "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_dns_challenge() {
  # Canonical create alias: --migration-dns-challenge <pair-id>
  soviez_migration_dns_challenge_create "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_PLAN_ID:-}"
}

soviez_cmd_migration_dns_show() {
  soviez_migration_dns_challenge_load "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}"
}

soviez_cmd_migration_dns_try_again() {
  soviez_migration_dns_challenge_try_again "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}"
}

soviez_cmd_migration_dns_abort() {
  soviez_migration_dns_challenge_abort "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}"
}

soviez_cmd_migration_landing_status() {
  soviez_cmd_migration_status
}

soviez_cmd_migration_tls_status() {
  soviez_cmd_migration_status
}

soviez_cmd_migration_dns_instructions() {
  soviez_migration_dns_instructions_export "${SOVIEZ_CLI_MIG_CHALLENGE_ID:-}" "${SOVIEZ_CLI_MIG_OUTPUT:-}"
}

soviez_cmd_migration_landing_prepare() {
  soviez_migration_landing_prepare "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_landing_cleanup() {
  soviez_migration_landing_cleanup "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_tls_prepare() {
  soviez_migration_tls_prepare "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_FQDN:-}"
}

soviez_cmd_migration_tls_revoke() {
  soviez_migration_tls_revoke "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_FQDN:-}"
}

soviez_cmd_migration_routing_readiness() {
  soviez_migration_routing_readiness_run "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_routing_show() {
  soviez_migration_routing_plan_show "${SOVIEZ_CLI_MIG_PLAN_ID:-}"
}

soviez_cmd_migration_domain_abort() {
  soviez_migration_domain_abort "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

# --- Phase 19 transfer commands ---

soviez_cmd_migration_transfer_plan() {
  soviez_migration_transfer_plan_run \
    "${SOVIEZ_CLI_MIG_PAIR_ID:-}" \
    "${SOVIEZ_CLI_MIG_ROUTING_PLAN_ID:-}"
}

soviez_cmd_migration_transfer_plan_show() {
  soviez_migration_transfer_plan_show "${SOVIEZ_CLI_MIG_PLAN_ID:-${SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID:-}}"
}

soviez_cmd_migration_presync() {
  soviez_migration_presync_run \
    "${SOVIEZ_CLI_MIG_PAIR_ID:-}" \
    "${SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID:-${SOVIEZ_CLI_MIG_PLAN_ID:-}}"
}

soviez_cmd_migration_presync_status() {
  soviez_migration_presync_status "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_start() {
  soviez_migration_transfer_start \
    "${SOVIEZ_CLI_MIG_PAIR_ID:-}" \
    "${SOVIEZ_CLI_MIG_ROUTING_PLAN_ID:-}"
}

soviez_cmd_migration_transfer_status() {
  soviez_migration_transfer_status "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_pause() {
  soviez_migration_transfer_pause "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_resume() {
  soviez_migration_transfer_resume "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_cancel() {
  soviez_migration_transfer_cancel "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_retry() {
  # Retry = resume from registry after revalidation
  soviez_migration_transfer_resume "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_recover() {
  soviez_migration_transfer_recover "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_destination_verify() {
  soviez_migration_destination_verify "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_abort() {
  soviez_migration_transfer_abort "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_transfer_cleanup() {
  local delete_staging=0
  [[ "${SOVIEZ_CLI_CONFIRM:-0}" == "1" || "${SOVIEZ_CLI_YES:-0}" == "1" ]] && \
    [[ "${SOVIEZ_CLI_MIG_DELETE_STAGING:-0}" == "1" ]] && delete_staging=1
  soviez_migration_transfer_cleanup "${SOVIEZ_CLI_OP_ID:-}" "$delete_staging"
}

soviez_cmd_migration_stage_mark_mandatory() {
  soviez_migration_stage_mark_mandatory "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_STAGE_ID:-}"
}

soviez_cmd_migration_stage_mark_optional() {
  soviez_migration_stage_mark_optional "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "${SOVIEZ_CLI_MIG_STAGE_ID:-}"
}

# --- Phase 20 authorization / activation ---

soviez_cmd_migration_authorization_plan() {
  soviez_migration_authorization_plan "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_authorization_show() {
  soviez_migration_authorization_show "${SOVIEZ_CLI_MIG_AUTH_ID:-}"
}

soviez_cmd_migration_activate_destination() {
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  # Commit if auth id not provided
  if [[ -z "${SOVIEZ_CLI_MIG_AUTH_ID:-}${SOVIEZ_MIG_P20_AUTH_ID:-}" ]]; then
    local receipt
    receipt="$(soviez_migration_authorization_commit "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "$confirm")"
    export SOVIEZ_MIG_P20_AUTH_ID="$(soviez_json_get "$receipt" authorization_id)"
  fi
  soviez_migration_destination_activate "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_activation_status() {
  soviez_migration_activation_status "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_AUTH_ID:-}}"
}

soviez_cmd_migration_activation_retry() {
  soviez_cmd_migration_activate_destination
}

soviez_cmd_migration_activation_recover() {
  soviez_migration_authorization_recover "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_source_grace_status() {
  soviez_migration_source_grace_status "${SOVIEZ_CLI_MIG_TARGET:-${SOVIEZ_CLI_MIG_PAIR_ID:-}}"
}

soviez_cmd_migration_stage_rebind_status() {
  local op="${SOVIEZ_CLI_OP_ID:-}"
  local auth
  auth="$(soviez_json_get "$(cat "$SOVIEZ_MIG_ROOT/ops/$op/authorization.json")" authorization_id 2>/dev/null || true)"
  [[ -n "$auth" ]] || auth="${SOVIEZ_CLI_MIG_AUTH_ID:-}"
  cat "$SOVIEZ_MIG_ROOT/activation/$auth/stage_rebinds.json"
}

soviez_cmd_migration_phase21_readiness() {
  soviez_migration_phase21_readiness "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_AUTH_ID:-}}"
}

soviez_cmd_migration_phase21_readiness_show() {
  soviez_migration_phase21_readiness_show "${SOVIEZ_CLI_MIG_REPORT_ID:-}"
}

soviez_cmd_migration_authorization_export() {
  soviez_migration_authorization_export "${SOVIEZ_CLI_MIG_AUTH_ID:-}" "${SOVIEZ_CLI_MIG_OUTPUT:-}"
}

soviez_cmd_migration_authorization_import() {
  soviez_migration_authorization_import "${SOVIEZ_CLI_MIG_IMPORT_PATH:-}"
}
