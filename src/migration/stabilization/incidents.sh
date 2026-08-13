# shellcheck shell=bash

soviez_migration_p22_incidents_clear() {
  local sample="$1"
  [[ "$(soviez_json_get "$sample" incidents)" -eq 0 ]] || return 1
  return 0
}
