# shellcheck shell=bash

soviez_migration_p22_archive_infrastructure() {
  local op_id="$1"
  local out
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/infrastructure.json"
  mkdir -p "$(dirname "$out")"
  printf '{"host_retained":true,"volumes_retained":true,"termination_authorized":false}\n' > "$out"
  cat "$out"
}
