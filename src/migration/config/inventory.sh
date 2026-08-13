# shellcheck shell=bash

soviez_migration_config_inventory() {
  local pair_id="$1"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_CONFIG_JSON:-}" ]]; then
    printf '%s\n' "$SOVIEZ_MIG_FIXTURE_CONFIG_JSON"
    return 0
  fi
  printf '{"settings":{"web.base.url":"http://staging.local","db_host":"127.0.0.1"},"secrets_detected":["smtp.password","payment.api_key"]}\n'
}
