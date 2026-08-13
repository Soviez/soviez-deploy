# shellcheck shell=bash

soviez_cmd_restore_run() {
  local target="${SOVIEZ_CLI_RESTORE_TARGET:-${SOVIEZ_CLI_TARGET:-}}"
  local backup_id="${SOVIEZ_CLI_BACKUP_ID:-${SOVIEZ_CLI_RESTORE_BACKUP:-}}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_restore_run "$target" "$backup_id" "$confirm"
}

soviez_cmd_restore_status() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_restore_die RESTORE_TARGET_REQUIRED "operation-id required"
  soviez_restore_paths_init
  local sf
  sf="$(soviez_restore_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_restore_die RESTORE_RECOVERY_REQUIRED "Unknown restore operation: $op_id"
  cat "$sf"
  soviez_restore_safety_window_info "$op_id" 2>/dev/null || true
}

soviez_cmd_restore_cancel() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_restore_die RESTORE_TARGET_REQUIRED "operation-id required"
  soviez_restore_paths_init
  local sf state
  sf="$(soviez_restore_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_restore_die RESTORE_TARGET_INVALID "Unknown operation"
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  case "$state" in
    switching|validating_production)
      soviez_restore_die RESTORE_RECOVERY_REQUIRED "Cannot cancel during $state"
      ;;
    completed|canceled|failed_terminal)
      soviez_restore_ok RESTORE_ALREADY_TERMINAL "Already terminal: $state"
      return 0
      ;;
  esac
  soviez_restore_candidate_cleanup "$op_id" || true
  soviez_restore_state_write "$op_id" canceled canceled "{}"
  soviez_restore_ok RESTORE_CANCELED "Canceled $op_id"
}

soviez_cmd_restore_retry() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_restore_die RESTORE_TARGET_REQUIRED "operation-id required"
  soviez_restore_paths_init
  local sf state
  sf="$(soviez_restore_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_restore_die RESTORE_RECOVERY_REQUIRED "Missing state"
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  case "$state" in
    failed_retryable|waiting_for_switch)
      local prod backup confirm
      prod="$(cat "$(soviez_restore_op_dir "$op_id")/production.json")"
      backup="$(cat "$(soviez_restore_op_dir "$op_id")/backup.json")"
      confirm="${SOVIEZ_CLI_CONFIRM:-1}"
      soviez_restore_validate_candidate "$op_id" "$prod" >/dev/null
      soviez_restore_state_write "$op_id" waiting_for_switch waiting_for_switch "{}"
      soviez_restore_ok RESTORE_RETRY_OK "Retry advanced to waiting_for_switch"
      ;;
    *)
      soviez_restore_die RESTORE_RECOVERY_REQUIRED "State $state is not safely retryable"
      ;;
  esac
}

soviez_cmd_restore_recover() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  soviez_restore_recover "$op_id"
}

soviez_cmd_restore_rollback() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_restore_die RESTORE_TARGET_REQUIRED "operation-id required"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ "$confirm" == "1" ]] || soviez_restore_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Rollback requires --confirm"
  local safety
  safety="$(soviez_restore_safety_window_info "$op_id")"
  local available
  available="$(soviez_json_get "$safety" rollback_available)"
  [[ "$available" == "true" || "$available" == "True" ]] \
    || soviez_restore_die RESTORE_ROLLBACK_FAILED "Safety window expired"
  soviez_restore_state_write "$op_id" rollback_running operator_rollback "{}"
  soviez_restore_rollback "$op_id"
  soviez_restore_state_write "$op_id" completed rolled_back "{}"
}

soviez_cmd_restore_cleanup() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ "$confirm" == "1" ]] || soviez_restore_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Cleanup requires --confirm"
  soviez_restore_candidate_cleanup "$op_id"
  soviez_restore_ok RESTORE_CLEANUP_OK "Candidate cleaned for $op_id"
}

soviez_cmd_restore_as_stage() {
  local backup_id="${SOVIEZ_CLI_BACKUP_ID:-}"
  local domain="${SOVIEZ_CLI_STAGE_DOMAIN:-}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_restore_as_stage "$backup_id" "$domain" "$confirm"
}

soviez_cmd_restore_test() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  soviez_backup_restore_test "$backup_id"
}
