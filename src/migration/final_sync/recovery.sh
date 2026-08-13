# shellcheck shell=bash

soviez_migration_final_sync_recovery() {
  local pair_id="$1" op_id="$2"
  soviez_migration_freeze_reconcile "$pair_id" "$op_id"
  soviez_migration_transfer_state_merge "$op_id" '{"checkpoint":"final_sync_recovered","source_write_freeze":false}' 
}
