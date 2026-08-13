# shellcheck shell=bash

soviez_migration_config_transfer() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local inv sanitized out_dir
  out_dir="$(soviez_migration_transfer_op_dir "$op_id")/config"
  mkdir -p "$out_dir"
  inv="$(soviez_migration_config_inventory "$pair_id")"
  sanitized="$(soviez_migration_config_sanitize "$inv")"
  printf '%s' "$sanitized" > "$out_dir/sanitized.json"
  soviez_migration_config_secret_inventory "$inv" "$out_dir/secret_inventory.json" >/dev/null
  # Never auto-transfer secrets
  if [[ "$(soviez_json_get "$(cat "$out_dir/secret_inventory.json")" automatic_secret_transfer)" == "true" ]]; then
    soviez_migration_die MIGRATION_SECRET_TRANSFER_NOT_AUTHORIZED "Secret transfer not authorized"
  fi
  printf '{"status":"config_transferred","sanitized":true,"secrets_excluded":true}\n'
}
