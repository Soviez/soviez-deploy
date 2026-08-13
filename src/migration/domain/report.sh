# shellcheck shell=bash

soviez_migration_domain_plan_report() {
  local plan_id="$1"
  local path
  path="$(soviez_migration_domain_plan_dir "$plan_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown domain plan: $plan_id"
  cat "$path"
}

soviez_migration_domain_plan_show() {
  soviez_migration_domain_plan_report "$1"
}
