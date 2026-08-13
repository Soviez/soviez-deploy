# shellcheck shell=bash

soviez_migration_staging_database_prepare() {
  local staging_id="$1"
  mkdir -p "$(soviez_migration_staging_dir "$staging_id")/database"
  printf '{"status":"prepared"}\n'
}
