# shellcheck shell=bash

soviez_migration_p22_finalization_recover() {
  local archive_op_id="$1"
  soviez_migration_source_license_finalize "$archive_op_id"
}
