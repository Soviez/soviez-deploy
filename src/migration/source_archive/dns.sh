# shellcheck shell=bash

soviez_migration_p22_archive_dns() {
  local op_id="$1" cutover_id="${2:-}"
  local out snap
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/dns_rollback_snapshot.json"
  mkdir -p "$(dirname "$out")"
  snap="$(soviez_migration_cutover_op_dir "$cutover_id")/dns_rollback_snapshot.json"
  if [[ -f "$snap" ]]; then
    cp -f "$snap" "$out"
  else
    printf '{"retained":true,"manual_recovery_only":true,"deleted":false}\n' > "$out"
  fi
  cat "$out"
}
