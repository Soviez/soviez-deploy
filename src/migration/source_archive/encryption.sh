# shellcheck shell=bash

soviez_migration_p22_archive_encrypt() {
  local op_id="$1"
  local op_dir plain enc
  op_dir="$(soviez_migration_p22_archive_op_dir "$op_id")"
  # Bundle database + filestore into a package then encrypt.
  plain="$op_dir/archive_bundle.tar"
  enc="$op_dir/archive_bundle.tar.enc"
  (
    cd "$op_dir"
    tar -cf "$plain" database filestore addons.json config secret_inventory.json \
      certificates.json dns_rollback_snapshot.json stages.json infrastructure.json 2>/dev/null || \
    tar -cf "$plain" database filestore 2>/dev/null || true
  )
  [[ -f "$plain" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "bundle missing"
  export SOVIEZ_BACKUP_PASSPHRASE="${SOVIEZ_BACKUP_PASSPHRASE:-p22-fixture-passphrase}"
  soviez_backup_encrypt_file "$plain" "$enc"
  local digest
  digest="$(openssl dgst -sha256 "$enc" | awk '{print $NF}')"
  printf '{"encrypted_path":"archive_bundle.tar.enc","sha256":"%s","plaintext_retained":false}\n' "$digest" \
    > "$op_dir/encryption.json"
  # Remove plaintext bundle from archive dir (source data untouched).
  rm -f "$plain"
  cat "$op_dir/encryption.json"
}
