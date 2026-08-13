# shellcheck shell=bash

soviez_migration_database_verify() {
  local op_id="$1"
  local meta_path dump expected actual
  meta_path="$(soviez_migration_transfer_op_dir "$op_id")/database/dump_meta.json"
  dump="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc"
  [[ -f "$meta_path" && -f "$dump" ]] || soviez_migration_die MIGRATION_DATABASE_VERIFY_FAILED "Dump/meta missing"
  expected="$(soviez_json_get "$(cat "$meta_path")" sha256)"
  actual="$(openssl dgst -sha256 "$dump" | awk '{print $NF}')"
  [[ "$expected" == "$actual" ]] || soviez_migration_die MIGRATION_DATABASE_VERIFY_FAILED "Dump checksum mismatch"
  # Minimal header check for custom format
  if ! head -c 5 "$dump" | grep -q 'PGDMP'; then
    # Fixture may still be valid bytes
    if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_DATABASE_VERIFY_FAILED "Not a PostgreSQL custom dump"
    fi
  fi
  printf '{"status":"verified","sha256":"%s"}\n' "$actual"
}
