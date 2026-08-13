# shellcheck shell=bash

soviez_migration_p22_retirement_suspend_check() {
  local source_id="$1"
  local statef
  statef="$(soviez_migration_p22_suspend_state_path "$source_id")"
  [[ -f "$statef" ]] || soviez_migration_die MIGRATION_RETIREMENT_NOT_READY "runtime not suspended"
  [[ "$(soviez_json_get "$(cat "$statef")" suspended)" == "True" || "$(soviez_json_get "$(cat "$statef")" suspended)" == "true" ]] || \
    soviez_migration_die MIGRATION_RETIREMENT_NOT_READY "runtime not suspended"
  cat "$statef"
}
