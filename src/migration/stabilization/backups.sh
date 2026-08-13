# shellcheck shell=bash

soviez_migration_p22_backups_ok() {
  local sample="$1"
  [[ "$(soviez_json_get "$sample" backups)" == "ok" ]] || return 1
  return 0
}
