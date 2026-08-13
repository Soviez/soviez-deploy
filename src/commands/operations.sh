# shellcheck shell=bash

soviez_cmd_operations_list() { soviez_ops_paths_init; soviez_ops_registry_list "$@"; }
soviez_cmd_operation_status() {
  soviez_ops_paths_init
  # Status reads canonical directly — migrate-on-read is compatibility fallback only.
  if [[ ! -f "$(soviez_ops_canonical_state_path "$1")" ]]; then
    soviez_ops_registry_get "$1" >/dev/null 2>&1 || soviez_ops_migrate_one "$1" || true
  elif soviez_ops_sync_is_pending "$1" 2>/dev/null; then
    soviez_ops_sync_reconcile "$1" >/dev/null 2>&1 || true
  fi
  soviez_ops_print_status "$1"
}
soviez_cmd_operation_reattach() {
  local op_id="$1" record type
  soviez_ops_paths_init
  if [[ ! -f "$(soviez_ops_canonical_state_path "$op_id")" ]]; then
    soviez_ops_registry_get "$op_id" >/dev/null 2>&1 || soviez_ops_migrate_one "$op_id" || true
  elif soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
    soviez_ops_sync_reconcile "$op_id" >/dev/null 2>&1 || true
  fi
  soviez_ops_print_status "$op_id"
  record="$(cat "$(soviez_ops_canonical_state_path "$op_id")" 2>/dev/null || soviez_ops_registry_get "$op_id")"
  type="$(soviez_json_get "$record" operation_type)"
  soviez_ops_adapter_reattach "$op_id" "$type"
}
soviez_cmd_operation_cancel() { soviez_ops_paths_init; soviez_ops_cancel "$@"; }
soviez_cmd_operation_retry() { soviez_ops_paths_init; soviez_ops_retry "$@"; }
soviez_cmd_operation_recover() { soviez_ops_paths_init; soviez_ops_recover "$@"; }
soviez_cmd_operation_logs() { soviez_ops_paths_init; soviez_ops_log_tail "$@"; }
soviez_cmd_operation_reconcile() {
  soviez_ops_paths_init
  if [[ -n "${1:-}" ]]; then soviez_ops_reconcile_one "$1"; else soviez_ops_reconcile_all; fi
}
