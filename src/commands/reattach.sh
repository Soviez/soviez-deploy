# shellcheck shell=bash

soviez_cmd_reattach_run() {
  local op_id="$SOVIEZ_CLI_OP_ID"
  local state_file
  state_file="$(soviez_operation_state_file "$op_id")"
  [[ -f "$state_file" ]] || soviez_die "$SOVIEZ_ERR_STATE" "Operation not found: $op_id"

  local state
  state="$(soviez_op_read_state "$op_id")"
  soviez_log_info "Reattaching to operation $op_id (state=$state)"

  if soviez_systemd_reattach "$op_id"; then
    soviez_log_info "Worker heartbeat present"
  fi

  case "$state" in
    completed|failed_terminal|canceled)
      soviez_log_info "Operation already terminal: $state"
      ;;
    manual_activation_pending|completed_activation_pending|activation_pending)
      SOVIEZ_CLI_OP_ID="$op_id"
      soviez_cmd_new_run
      ;;
    *)
      SOVIEZ_CLI_OP_ID="$op_id"
      soviez_cmd_new_run
      ;;
  esac
}
