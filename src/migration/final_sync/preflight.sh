# shellcheck shell=bash

soviez_migration_final_sync_preflight() {
  local pair_id="$1" routing_plan_id="$2" op_id="${3:-}"
  soviez_migration_assert_no_cutover_or_token
  soviez_migration_transfer_require_routing "$pair_id" "$routing_plan_id"
  soviez_migration_transfer_backup_gate "$pair_id" "$op_id" >/dev/null
  printf '{"status":"preflight_pass","migration_pair_id":"%s","routing_plan_id":"%s"}\n' \
    "$pair_id" "$routing_plan_id"
}
