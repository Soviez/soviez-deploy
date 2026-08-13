# shellcheck shell=bash

soviez_migration_staging_filestore_prepare() {
  local staging_id="$1"
  mkdir -p "$(soviez_migration_staging_dir "$staging_id")/filestore"
  printf '{"status":"prepared"}\n'
}
