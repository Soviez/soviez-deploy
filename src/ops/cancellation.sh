# shellcheck shell=bash

soviez_ops_cancel() {
  local op_id="$1" reason="${2:-Canceled by operator}" yes="${3:-}" record state checkpoint boundary type
  record="$(cat "$(soviez_ops_canonical_state_path "$op_id")")" || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  state="$(soviez_json_get "$record" current_state)"
  checkpoint="$(soviez_json_get "$record" current_checkpoint)"
  type="$(soviez_json_get "$record" operation_type)"
  case "$state" in
    completed|canceled|failed_terminal)
      soviez_ops_die OPERATION_ALREADY_TERMINAL "Operation already terminal: $state"
      ;;
    created|queued|waiting|retry_scheduled)
      soviez_ops_transition "$op_id" canceled "$checkpoint"
      soviez_ops_ok OPERATION_CANCEL_ACCEPTED "Canceled before protected work"
      ;;
    running|starting|cancel_requested)
      boundary="$(soviez_ops_adapter_cancel_boundary "$type" "$checkpoint")"
      if [[ "$boundary" == "irreversible" ]]; then
        soviez_ops_die OPERATION_CANCEL_NOT_ALLOWED "Checkpoint is irreversible: $checkpoint"
      fi
      if [[ "$boundary" == "rollback" && "$yes" != "--yes" && "$yes" != "yes" ]]; then
        soviez_ops_die OPERATION_CANCEL_REQUIRES_CONFIRMATION "Cancel requires rollback confirmation (--yes)"
      fi
      soviez_ops_transition "$op_id" cancel_requested "$checkpoint"
      if [[ "$boundary" == "rollback" ]]; then
        soviez_ops_transition "$op_id" canceling "$checkpoint"
        soviez_ops_transition "$op_id" rollback_running "$checkpoint"
        soviez_ops_ok OPERATION_CANCEL_ROLLBACK_STARTED "Rollback started"
      else
        soviez_ops_ok OPERATION_CANCEL_ACCEPTED "Cancel requested; waiting for safe boundary"
      fi
      ;;
    *)
      soviez_ops_die OPERATION_CANCEL_NOT_ALLOWED "Cannot cancel state: $state"
      ;;
  esac
}
