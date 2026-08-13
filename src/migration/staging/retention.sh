# shellcheck shell=bash

soviez_migration_staging_retention_set() {
  local staging_id="$1" hours="${2:-24}"
  local dir expires
  dir="$(soviez_migration_staging_dir "$staging_id")"
  expires="$(soviez_migration_expires_iso $(( hours * 3600 )))"
  printf '{"staging_id":"%s","retain_hours":%s,"expires_at":"%s","pinned":false}\n' \
    "$staging_id" "$hours" "$expires" > "$dir/retention.json"
  cat "$dir/retention.json"
}
