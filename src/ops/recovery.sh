# shellcheck shell=bash

soviez_ops_recover() {
  local op_id="$1" yes="${2:-}" decision
  decision="$(soviez_ops_reconcile_one "$op_id")"
  case "$decision" in
    healthy|attach_existing) soviez_ops_ok "$decision" "Operation has an active worker" ;;
    resume_safe|retry_scheduled) soviez_ops_retry "$op_id" "$yes" ;;
    recovery_required) soviez_ops_ok recovery_required "Inspect resources; destructive recovery requires --yes" ;;
    cleanup_terminal_metadata) soviez_ops_history_append "$op_id"; soviez_ops_ok cleanup_terminal_metadata "History preserved" ;;
    *) soviez_ops_die OPERATION_RECOVERY_REQUIRED "Unable to reconcile operation" ;;
  esac
}
