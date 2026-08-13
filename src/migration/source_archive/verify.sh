# shellcheck shell=bash

soviez_migration_p22_archive_verify() {
  local op_id="$1"
  local op_dir manifest enc
  op_dir="$(soviez_migration_p22_archive_op_dir "$op_id")"
  manifest="$(soviez_migration_p22_archive_manifest_path "$op_id")"
  enc="$op_dir/archive_bundle.tar.enc"
  [[ -f "$manifest" && -f "$enc" ]] || \
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_VERIFY_FAILED "archive artifacts missing"
  soviez_migration_verify_object_signature "$manifest" || \
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_VERIFY_FAILED "manifest signature invalid"
  local expected actual
  expected="$(soviez_json_get "$(cat "$manifest")" encrypted_sha256)"
  actual="$(openssl dgst -sha256 "$enc" | awk '{print $NF}')"
  [[ "$expected" == "$actual" ]] || \
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_VERIFY_FAILED "encrypted checksum mismatch"
  [[ "$(soviez_json_get "$(cat "$manifest")" purge_authorized)" == "False" || "$(soviez_json_get "$(cat "$manifest")" purge_authorized)" == "false" ]] || \
    soviez_migration_die MIGRATION_PURGE_NOT_AUTHORIZED "manifest must have purge_authorized=false"
  [[ "$(soviez_json_get "$(cat "$manifest")" deletion_performed)" == "False" || "$(soviez_json_get "$(cat "$manifest")" deletion_performed)" == "false" ]] || \
    soviez_migration_die MIGRATION_SOURCE_DELETE_NOT_AUTHORIZED "manifest must have deletion_performed=false"
  local pinned
  pinned="$(soviez_json_get "$(cat "$manifest")" independent_recovery_copy)"
  [[ -e "$pinned" ]] || soviez_migration_die MIGRATION_SOURCE_BACKUP_REQUIRED "pinned recovery copy missing"
  printf '{"verified":true,"operation_id":"%s"}\n' "$op_id"
}
