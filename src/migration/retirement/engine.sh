# shellcheck shell=bash

soviez_migration_source_retirement_status() {
  local source_id="${1:-}"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_RETIREMENT_STATUS"
  soviez_migration_p22_paths_init
  soviez_migration_p22_retirement_report "$source_id"
}
