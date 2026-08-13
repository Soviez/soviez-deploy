# shellcheck shell=bash

soviez_migration_p22_stages_ok() {
  local sample="$1"
  [[ "$(soviez_json_get "$sample" stages)" == "ok" ]] || return 1
  return 0
}
