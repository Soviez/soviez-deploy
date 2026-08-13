# shellcheck shell=bash

soviez_migration_landing_health_check() {
  local site_dir="$1"
  local hz="$site_dir/www/healthz"
  [[ -f "$hz" ]] || soviez_migration_die MIGRATION_LANDING_HEALTH_FAILED "healthz missing"
  grep -q '"ok"[[:space:]]*:[[:space:]]*true' "$hz" || \
    soviez_migration_die MIGRATION_LANDING_HEALTH_FAILED "healthz not ok"
  printf '{"ok":true,"path":"%s"}\n' "$hz"
}
