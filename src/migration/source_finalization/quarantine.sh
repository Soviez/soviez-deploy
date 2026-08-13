# shellcheck shell=bash

soviez_migration_p22_quarantine() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/quarantine.json"
  mkdir -p "$(dirname "$out")"
  printf '{"quarantined":true,"public_access":false}\n' > "$out"
  cat "$out"
}
