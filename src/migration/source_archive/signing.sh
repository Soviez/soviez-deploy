# shellcheck shell=bash

soviez_migration_p22_archive_sign_manifest() {
  local op_id="$1"
  local manifest
  manifest="$(soviez_migration_p22_archive_manifest_path "$op_id")"
  [[ -f "$manifest" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_VERIFY_FAILED "manifest missing"
  soviez_migration_sign_object_file "$manifest"
  cat "$manifest"
}
