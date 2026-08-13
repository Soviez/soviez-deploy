# shellcheck shell=bash

soviez_migration_domain_strategy_default() {
  local production_fqdn="$1"
  [[ -n "$production_fqdn" ]] || soviez_migration_die MIGRATION_DOMAIN_STRATEGY_REQUIRED "Production domain required for strategy"
  printf 'migrate.%s\n' "$production_fqdn"
}

soviez_migration_domain_strategy_resolve() {
  local production_fqdn="$1" override="${2:-}"
  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
    return 0
  fi
  soviez_migration_domain_strategy_default "$production_fqdn"
}
