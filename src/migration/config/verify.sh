# shellcheck shell=bash

soviez_migration_config_verify() {
  local op_id="$1"
  local path
  path="$(soviez_migration_transfer_op_dir "$op_id")/config/sanitized.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_CONFIG_TRANSFER_FAILED "Sanitized config missing"
  # Ensure no obvious secrets remain
  if grep -Eiq 'password|api_key|private_key|smtp\.password' "$path"; then
    soviez_migration_die MIGRATION_SECRET_TRANSFER_NOT_AUTHORIZED "Secret-like keys found in sanitized config"
  fi
  printf '{"status":"verified"}\n'
}
