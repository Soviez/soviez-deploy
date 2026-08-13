# shellcheck shell=bash

soviez_migration_p22_integrations_ok() {
  local sample="$1"
  [[ "$(soviez_json_get "$sample" webhook)" == "ok" ]] || return 1
  [[ "$(soviez_json_get "$sample" payment)" == "ok" ]] || return 1
  [[ "$(soviez_json_get "$sample" mail)" == "ok" ]] || return 1
  return 0
}
