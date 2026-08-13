# shellcheck shell=bash

soviez_migration_staging_neutralize() {
  local staging_id="$1"
  local dir
  dir="$(soviez_migration_staging_dir "$staging_id")"
  mkdir -p "$dir"
  cat > "$dir/neutralization.json" <<EOF
{"mail_neutralized":true,"cron_neutralized":true,"payments_neutralized":true,"webhooks_neutralized":true,"public_routing_enabled":false,"notifications_disabled":true}
EOF
  # Update identity
  if [[ -f "$dir/identity.json" ]]; then
    soviez_json_merge_file "$dir/identity.json" '{"mail_neutralized":true,"cron_neutralized":true,"payments_neutralized":true,"webhooks_neutralized":true,"public_routing_enabled":false}' 2>/dev/null || true
  fi
  cat "$dir/neutralization.json"
}
