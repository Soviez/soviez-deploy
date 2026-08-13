# shellcheck shell=bash

soviez_migration_p22_retirement_inventory_check() {
  local source_id="$1"
  local inv
  inv="$(soviez_migration_p22_retirement_inventory "$source_id")"
  local unk
  unk="$(soviez_json_get "$inv" unknown_count)"
  [[ "${unk:-0}" -eq 0 ]] || soviez_migration_die MIGRATION_RETIREMENT_NOT_READY "unknown resources BLOCK"
  printf '%s\n' "$inv"
}
