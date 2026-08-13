# shellcheck shell=bash

soviez_migration_stages_verify() {
  local staging_id="$1"
  local dir
  dir="$(soviez_migration_staging_dir "$staging_id")/stages"
  [[ -d "$dir" ]] || { printf '{"status":"verified","count":0}\n'; return 0; }
  local count=0
  shopt -s nullglob
  for s in "$dir"/*/state.json; do
    count=$((count+1))
    [[ "$(soviez_json_get "$(cat "$s")" public_route)" != "true" ]] || \
      soviez_migration_die MIGRATION_DESTINATION_PUBLIC_ROUTE_DETECTED "Stage public route detected"
  done
  printf '{"status":"verified","count":%s}\n' "$count"
}
