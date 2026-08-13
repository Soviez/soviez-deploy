# shellcheck shell=bash

soviez_migration_rollback_window_close_status() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_ROLLBACK_WINDOW_CLOSE"
  soviez_migration_p22_paths_init
  local f
  f="$(soviez_migration_p22_closure_receipt_path "$op_id")"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_NOT_FOUND "closure receipt not found"
  cat "$f"
}
