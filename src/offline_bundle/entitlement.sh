# shellcheck shell=bash
# Provider-neutral entitlement gate: product_updates + offline_update_bundle.

soviez_offline_entitlement_require() {
  local grants_json="$1" license_id="$2"
  # grants_json: {"capabilities":["product_updates","offline_update_bundle"],"status":"active",...}
  local caps status
  caps="$(soviez_json_get "$grants_json" capabilities 2>/dev/null || echo "[]")"
  status="$(soviez_json_get "$grants_json" status 2>/dev/null || echo "")"
  case "$status" in
    revoked|refunded|disputed)
      soviez_offline_die OFFLINE_UPDATE_ENTITLEMENT_REVOKED "Grant status=$status"
      ;;
    expired)
      soviez_offline_die OFFLINE_UPDATE_ENTITLEMENT_EXPIRED "Grant expired"
      ;;
  esac
  if ! printf '%s' "$caps" | grep -q 'product_updates'; then
    soviez_offline_die OFFLINE_UPDATE_PRODUCT_UPDATES_REQUIRED "product_updates required"
  fi
  if ! printf '%s' "$caps" | grep -q 'offline_update_bundle'; then
    soviez_offline_die OFFLINE_UPDATE_OFFLINE_CAPABILITY_REQUIRED "offline_update_bundle required"
  fi
  local grant_license
  grant_license="$(soviez_json_get "$grants_json" license_id 2>/dev/null || true)"
  if [[ -n "$grant_license" && "$grant_license" != "$license_id" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_LICENSE_MISMATCH "Grant license mismatch"
  fi
  # No quantity decrement — issuance is immutable metadata only
  return 0
}

soviez_offline_entitlement_fixture_ok() {
  local license_id="$1"
  printf '{"status":"active","license_id":"%s","capabilities":["product_updates","offline_update_bundle"],"quantity_consumed":0,"provider":"neutral"}\n' \
    "$license_id"
}
