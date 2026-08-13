# shellcheck shell=bash

soviez_cmd_migration_stabilization_status() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_stabilization_status "${SOVIEZ_CLI_OP_ID:-${SOVIEZ_CLI_MIG_CUTOVER_ID:-}}"
}
