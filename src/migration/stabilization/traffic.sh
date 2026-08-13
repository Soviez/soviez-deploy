# shellcheck shell=bash

soviez_migration_p22_traffic_checks() {
  local sample="$1"
  [[ "$(soviez_json_get "$sample" source_requests)" -eq 0 ]] || return 1
  [[ "$(soviez_json_get "$sample" duplicates)" -eq 0 ]] || return 1
  return 0
}
