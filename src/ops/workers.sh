# shellcheck shell=bash

soviez_ops_worker_identity() {
  local op_id="$1"
  printf 'soviez-worker:%s:%s\n' "$op_id" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op_id")")" worker_generation 2>/dev/null || echo 0)"
}

soviez_ops_worker_reattach() {
  local op_id="$1" decision
  decision="$(soviez_ops_reconcile_one "$op_id")"
  case "$decision" in
    healthy|attach_existing)
      soviez_ops_print_status "$op_id"
      soviez_ops_log_tail "$op_id" 50 || true
      ;;
    resume_safe)
      soviez_ops_print_status "$op_id"
      printf 'Reconcile: resume_safe — use --operation-retry or command-specific reattach\n'
      ;;
    recovery_required)
      soviez_ops_die OPERATION_RECOVERY_REQUIRED "Reattach unavailable; recovery required for $op_id"
      ;;
    *)
      soviez_ops_print_status "$op_id"
      ;;
  esac
}
