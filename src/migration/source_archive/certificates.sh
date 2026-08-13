# shellcheck shell=bash

soviez_migration_p22_archive_certificates() {
  local op_id="$1"
  local out
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/certificates.json"
  mkdir -p "$(dirname "$out")"
  # Retention metadata only — never revoke.
  printf '{"retained":true,"revoked":false,"revoke_authorized":false}\n' > "$out"
  cat "$out"
}
