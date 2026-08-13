# shellcheck shell=bash

soviez_migration_source_archive_recover() {
  local op_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_ARCHIVE"
  local state
  state="$(soviez_json_get "$(soviez_migration_source_archive_status "$op_id")" current_state)"
  case "$state" in
    verified|complete)
      soviez_migration_source_archive_status "$op_id"
      ;;
    failed|create_failed|verify_failed)
      soviez_migration_source_archive_retry "$op_id"
      ;;
    *)
      soviez_migration_die MIGRATION_RECOVERY_REQUIRED "archive recovery required for state=$state"
      ;;
  esac
}

soviez_migration_source_archive_retry() {
  local op_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_ARCHIVE"
  local st source_id cutover_id
  st="$(soviez_migration_source_archive_status "$op_id")"
  source_id="$(soviez_json_get "$st" source_id)"
  cutover_id="$(soviez_json_get "$st" cutover_id)"
  export SOVIEZ_MIG_P22_CUTOVER_ID="$cutover_id"
  soviez_migration_source_archive_start "$source_id" "$op_id"
}
