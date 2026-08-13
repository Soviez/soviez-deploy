# shellcheck shell=bash

soviez_migration_source_archive_status() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_ARCHIVE"
  soviez_migration_p22_paths_init
  local f
  f="$(soviez_migration_p22_archive_state_path "$op_id")"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_NOT_FOUND "archive operation not found"
  cat "$f"
}
