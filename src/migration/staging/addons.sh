# shellcheck shell=bash

soviez_migration_staging_addons_prepare() {
  local staging_id="$1"
  mkdir -p "$(soviez_migration_staging_dir "$staging_id")/addons"
  printf '{"status":"prepared"}\n'
}
