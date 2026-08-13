# shellcheck shell=bash

soviez_cmd_migration_rollback_window_close_plan() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_rollback_window_close_plan "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_CUTOVER_ID:-}}"
}

soviez_cmd_migration_rollback_window_close() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_rollback_window_close "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_CUTOVER_ID:-}}"
}

soviez_cmd_migration_rollback_window_close_status() {
  soviez_migration_rollback_window_close_status "${SOVIEZ_CLI_OP_ID:-}"
}
