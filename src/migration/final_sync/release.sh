# shellcheck shell=bash

soviez_migration_final_sync_release() {
  local pair_id="$1" op_id="$2"
  soviez_migration_freeze_release "$pair_id" "$op_id" "final_sync_release"
}
