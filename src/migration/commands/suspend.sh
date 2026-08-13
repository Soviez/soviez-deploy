# shellcheck shell=bash

soviez_cmd_migration_source_runtime_suspend() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_runtime_suspend "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_source_retirement_status() {
  soviez_migration_source_retirement_status "${SOVIEZ_CLI_MIG_SOURCE_ID:-${SOVIEZ_CLI_OP_ID:-}}"
}
