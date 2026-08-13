# shellcheck shell=bash

soviez_migration_final_sync_database() {
  local pair_id="$1" op_id="$2" manifest_id="$3" staging_id="$4"
  soviez_migration_database_dump "$pair_id" "$op_id" >/dev/null
  soviez_migration_database_verify "$op_id" >/dev/null
  soviez_migration_database_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null
  soviez_migration_database_restore "$pair_id" "$op_id" "$staging_id"
}
