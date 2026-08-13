# shellcheck shell=bash

soviez_cmd_migration_source_license_finalize() {
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_source_license_finalize "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_source_credentials_status() {
  soviez_migration_source_credentials_status "${SOVIEZ_CLI_OP_ID:-}"
}
