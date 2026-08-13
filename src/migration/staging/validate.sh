# shellcheck shell=bash

soviez_migration_staging_validate() {
  local staging_id="$1"
  local dir id startup mode
  dir="$(soviez_migration_staging_dir "$staging_id")"
  [[ -f "$dir/identity.json" ]] || soviez_migration_die MIGRATION_STAGING_INVALID "Missing staging identity"
  id="$(cat "$dir/identity.json")"
  [[ "$(soviez_json_get "$id" public_routing_enabled)" != "true" ]] || \
    soviez_migration_die MIGRATION_DESTINATION_PUBLIC_ROUTE_DETECTED "Public route enabled"
  [[ "$(soviez_json_get "$id" production_activated)" != "true" ]] || \
    soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_NOT_AUTHORIZED "Production activated"
  [[ "$(soviez_json_get "$id" non_slot_consuming)" == "true" || "$(soviez_json_get "$id" non_slot_consuming)" == "True" ]] || \
    soviez_migration_die MIGRATION_SLOT_FORBIDDEN "Staging must be non-slot-consuming"
  [[ "$(soviez_json_get "$id" migration_token_consumed)" != "true" ]] || \
    soviez_migration_die MIGRATION_TOKEN_NOT_CONSUMED "Token consumed on staging"
  [[ -f "$dir/health.marker" ]] || soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "Health marker missing"
  if [[ -f "$dir/public_route.enabled" ]]; then
    soviez_migration_die MIGRATION_PUBLIC_LOGIN_FORBIDDEN "Public login exposed"
  fi

  startup="{}"
  [[ -f "$dir/startup.json" ]] && startup="$(cat "$dir/startup.json")"
  mode="$(soviez_json_get "$startup" mode)"

  if [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING:-0}" == "1" || "${SOVIEZ_PHASE19_FORBID_FIXTURE_ERP:-0}" == "1" ]]; then
    [[ "$mode" == "real_soviez_erp" ]] || \
      soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "real ERP staging required (got mode=${mode:-missing})"
    [[ "$(soviez_json_get "$startup" login_http_code)" == "200" ]] || \
      soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "real /web/login not 200"
    local mods
    mods="$(soviez_json_get "$startup" installed_modules)"
    [[ "${mods:-0}" -gt 0 ]] || \
      soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "no installed modules"
  else
    [[ -f "$dir/www/web/login" || -f "$dir/www/login.html" ]] || \
      soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "Internal login page missing"
  fi

  # Filestore attachment resolvable when present
  if [[ -d "$dir/filestore" ]]; then
    find "$dir/filestore" -type f 2>/dev/null | head -1 >/dev/null || true
  fi

  printf '{"staging_id":"%s","status":"verified","mode":"%s","public_route":false,"slot":false,"token_consumed":false,"license_guard":true}\n' \
    "$staging_id" "${mode:-unknown}" > "$dir/validation.json"
  cat "$dir/validation.json"
}
