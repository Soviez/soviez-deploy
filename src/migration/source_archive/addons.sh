# shellcheck shell=bash

soviez_migration_p22_archive_addons() {
  local op_id="$1"
  local out
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/addons.json"
  mkdir -p "$(dirname "$out")"
  printf '{"addons":[],"archived":true,"deleted":false}\n' > "$out"
  cat "$out"
}
