# shellcheck shell=bash

soviez_cmd_update_run() {
  local target="${SOVIEZ_CLI_UPDATE_TARGET:-}"
  local release="${SOVIEZ_CLI_UPDATE_RELEASE:-}"
  local offline="${SOVIEZ_CLI_UPDATE_OFFLINE_PACKAGE:-}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_update_run "$target" "$release" "$offline" "$confirm"
}

soviez_cmd_update_status() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local sf
  sf="$(soviez_update_op_state_file "$op_id")"
  if [[ -f "$sf" ]]; then
    cat "$sf"
  elif declare -F soviez_ops_status >/dev/null 2>&1; then
    soviez_ops_status "$op_id"
  else
    soviez_update_die UPDATE_TARGET_INVALID "Unknown update operation: $op_id"
  fi
  soviez_update_safety_window_info "$op_id" 2>/dev/null || true
}

soviez_cmd_update_reattach() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local sf state checkpoint
  sf="$(soviez_update_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_update_die UPDATE_RECOVERY_REQUIRED "Cannot reattach: missing state"
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  checkpoint="$(soviez_json_get "$(cat "$sf")" checkpoint 2>/dev/null || true)"
  case "$state" in
    completed|canceled|failed_terminal) soviez_update_ok UPDATE_ALREADY_TERMINAL "Operation already terminal: $state"; return 0 ;;
    recovery_required) soviez_update_die UPDATE_RECOVERY_REQUIRED "Use --update-recover" ;;
  esac
  # Resume from waiting_for_switch or failed_retryable with confirm
  if [[ "$state" == "waiting_for_switch" || "$checkpoint" == "waiting_for_switch" ]]; then
    local prod digest confirm
    prod="$(cat "$(soviez_update_op_dir "$op_id")/production.json")"
    digest="$(cat "$(soviez_update_op_dir "$op_id")/target_digest.txt")"
    confirm="${SOVIEZ_CLI_CONFIRM:-1}"
    soviez_update_state_write "$op_id" switching switching "{}"
    soviez_update_switch "$op_id" "$prod" "$digest"
    soviez_update_state_write "$op_id" completed completed "{}"
    soviez_update_ok UPDATE_COMPLETED "Reattached switch completed"
    return 0
  fi
  soviez_update_ok UPDATE_REATTACHED "Reattached to $op_id state=$state"
}

soviez_cmd_update_cancel() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local sf checkpoint boundary
  sf="$(soviez_update_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_update_die UPDATE_TARGET_INVALID "Unknown operation"
  checkpoint="$(soviez_json_get "$(cat "$sf")" checkpoint 2>/dev/null || true)"
  boundary="$(soviez_update_cancel_boundary "$checkpoint")"
  case "$boundary" in
    irreversible) soviez_update_die UPDATE_CANCELLATION_NOT_SAFE "Cannot cancel during $checkpoint" ;;
    rollback)
      soviez_update_state_write "$op_id" rollback_running cancel_rollback "{}"
      soviez_update_rollback "$op_id" >/dev/null
      soviez_update_state_write "$op_id" canceled canceled "{}"
      ;;
    *)
      soviez_update_candidate_cleanup "$op_id" || true
      soviez_update_state_write "$op_id" canceled canceled "{}"
      ;;
  esac
  soviez_update_ok UPDATE_CANCELED "Canceled $op_id"
}

soviez_cmd_update_retry() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local sf state
  sf="$(soviez_update_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_update_die UPDATE_RECOVERY_REQUIRED "Missing state"
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  case "$state" in
    failed_retryable|retry_scheduled)
      local prod digest
      prod="$(cat "$(soviez_update_op_dir "$op_id")/production.json")"
      digest="$(cat "$(soviez_update_op_dir "$op_id")/target_digest.txt")"
      # Do not blindly rerun ambiguous migrations — only safe candidate upgrade retry
      soviez_update_state_write "$op_id" upgrading_candidate retry_upgrade "{}"
      soviez_update_upgrade_candidate "$op_id" "$digest"
      soviez_update_validate_candidate "$op_id" "$prod" "$digest"
      soviez_update_state_write "$op_id" waiting_for_switch waiting_for_switch "{}"
      soviez_update_ok UPDATE_RETRY_OK "Retry advanced to waiting_for_switch"
      ;;
    *) soviez_update_die UPDATE_RECOVERY_REQUIRED "State $state is not safely retryable" ;;
  esac
}

soviez_cmd_update_recover() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local sf
  sf="$(soviez_update_op_state_file "$op_id")"
  if [[ ! -f "$sf" ]]; then
    soviez_update_die UPDATE_RECOVERY_REQUIRED "Ambiguous missing state"
  fi
  if declare -F soviez_ops_sync_is_pending >/dev/null 2>&1; then
    if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
      soviez_ops_sync_reconcile "$op_id" 2>/dev/null || true
    fi
  fi
  local state
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  case "$state" in
    switching|rollback_running)
      soviez_update_state_write "$op_id" recovery_required recovery_required "{}"
      soviez_update_die UPDATE_RECOVERY_REQUIRED "Manual recovery required for ambiguous $state"
      ;;
    *)
      soviez_update_ok UPDATE_RECOVERED "Recovered view of $op_id ($state)"
      ;;
  esac
}

soviez_cmd_update_rollback() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  soviez_update_state_write "$op_id" rollback_running operator_rollback "{}"
  soviez_update_rollback "$op_id"
  soviez_update_state_write "$op_id" completed rolled_back "{}"
}

soviez_cmd_update_cleanup() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_update_die UPDATE_TARGET_REQUIRED "operation-id required"
  soviez_update_paths_init
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "$confirm" == "1" ]] || soviez_update_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Cleanup requires --confirm"
  local safety expires
  safety="$(soviez_update_safety_window_info "$op_id")"
  # Always allow cleanup of candidate; refuse deleting sole rollback set without confirm already given
  soviez_update_candidate_cleanup "$op_id"
  soviez_update_ok UPDATE_CLEANUP_OK "Candidate cleaned for $op_id (rollback set retained until safety window)"
}

soviez_cmd_update_image_status() {
  local production_id="${SOVIEZ_CLI_UPDATE_TARGET:-}"
  soviez_update_paths_init
  soviez_image_cleanup_paths_init
  soviez_image_status "$production_id"
}

soviez_cmd_update_image_cleanup() {
  local production_id="${SOVIEZ_CLI_UPDATE_TARGET:-}"
  local dry="${SOVIEZ_CLI_DRY_RUN:-0}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  local retry_op="${SOVIEZ_CLI_OP_ID:-}"
  soviez_update_paths_init
  soviez_image_cleanup_paths_init
  if [[ -n "$retry_op" && "${SOVIEZ_CLI_COMMAND:-}" == "update-image-cleanup-retry" ]]; then
    export SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED=1
    soviez_image_cleanup_scheduler_tick
    return 0
  fi
  soviez_image_cleanup_execute "$production_id" "$confirm" "" "$dry"
}
