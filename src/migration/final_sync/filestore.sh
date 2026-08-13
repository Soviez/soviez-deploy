# shellcheck shell=bash

soviez_migration_final_sync_filestore() {
  local pair_id="$1" op_id="$2" manifest_id="$3" staging_id="$4"
  soviez_migration_filestore_delta "$pair_id" "$op_id" "$manifest_id" >/dev/null
  soviez_migration_filestore_assemble "$op_id" "$staging_id" >/dev/null
  soviez_migration_filestore_reconcile "$op_id" "$staging_id"
}
