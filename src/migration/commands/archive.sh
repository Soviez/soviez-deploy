# shellcheck shell=bash

soviez_cmd_migration_source_archive_plan() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_archive_plan "${SOVIEZ_CLI_MIG_SOURCE_ID:-${SOVIEZ_CLI_OP_ID:-}}"
}

soviez_cmd_migration_source_archive_start() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_archive_start "${SOVIEZ_CLI_MIG_SOURCE_ID:-${SOVIEZ_CLI_OP_ID:-}}"
}

soviez_cmd_migration_source_archive_status() {
  soviez_migration_source_archive_status "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_source_archive_retry() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_archive_retry "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_source_archive_recover() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_archive_recover "${SOVIEZ_CLI_OP_ID:-}"
}
