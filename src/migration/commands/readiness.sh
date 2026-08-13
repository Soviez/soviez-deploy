# shellcheck shell=bash

soviez_cmd_migration_phase23_readiness() {
  soviez_migration_phase23_readiness "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_phase23_readiness_show() {
  soviez_migration_phase23_readiness_show "${SOVIEZ_CLI_MIG_REPORT_ID:-}"
}
