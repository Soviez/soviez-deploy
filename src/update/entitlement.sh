# shellcheck shell=bash

# Provider-neutral product_updates capability check for exact License.

soviez_update_entitlement_check() {
  local license_id="$1" production_id="$2" account_id="${3:-}"
  local body
  body="$(SOVIEZ_LIC="$license_id" SOVIEZ_PROD="$production_id" SOVIEZ_ACCT="$account_id" python3 - <<'PY'
import json,os
print(json.dumps({
  "capability":"product_updates",
  "license_id":os.environ["SOVIEZ_LIC"],
  "production_environment_id":os.environ["SOVIEZ_PROD"],
  "account_id":os.environ.get("SOVIEZ_ACCT") or None,
  "operation":"production_update",
},separators=(",",":")))
PY
)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON"
    return 0
  fi
  if [[ "${SOVIEZ_UPDATE_OFFLINE_MODE:-0}" == "1" ]]; then
    soviez_update_die UPDATE_ENTITLEMENT_UNAVAILABLE "Connected entitlement unavailable in offline mode; use --offline-package"
  fi
  if declare -F soviez_http_signed_post_json >/dev/null 2>&1; then
    soviez_http_signed_post_json "/api/installer/entitlements/product-updates/check" "$body"
    return 0
  fi
  soviez_update_die UPDATE_ENTITLEMENT_UNAVAILABLE "Entitlement client unavailable"
}

soviez_update_entitlement_assert() {
  local ent_json="$1" expected_license="$2" expected_account="${3:-}"
  local allowed source_type decision code
  allowed="$(soviez_json_get "$ent_json" allowed 2>/dev/null || soviez_json_get "$ent_json" ok 2>/dev/null || echo false)"
  source_type="$(soviez_json_get "$ent_json" source_type 2>/dev/null || soviez_json_get "$ent_json" sourceType 2>/dev/null || echo unknown)"
  decision="$(soviez_json_get "$ent_json" decision 2>/dev/null || true)"
  code="$(soviez_json_get "$ent_json" denial_code 2>/dev/null || soviez_json_get "$ent_json" code 2>/dev/null || true)"

  local grant_license grant_account
  grant_license="$(soviez_json_get "$ent_json" license_id 2>/dev/null || true)"
  grant_account="$(soviez_json_get "$ent_json" account_id 2>/dev/null || true)"

  case "$source_type" in
    legacy_monthly|monthly|technical_support_only)
      soviez_update_die UPDATE_MONTHLY_SUPPORT_DENIED "Legacy monthly technical support does not include product_updates"
      ;;
    unbound|unbound_legacy)
      soviez_update_die UPDATE_UNBOUND_GRANT_DENIED "Unbound legacy grants cannot authorize product_updates"
      ;;
  esac

  if [[ -n "$grant_license" && "$grant_license" != "null" && "$grant_license" != "$expected_license" ]]; then
    soviez_update_die UPDATE_WRONG_LICENSE "Grant license does not match Production license"
  fi
  if [[ -n "$expected_account" && -n "$grant_account" && "$grant_account" != "null" && "$grant_account" != "$expected_account" ]]; then
    soviez_update_die UPDATE_WRONG_ACCOUNT "Grant account does not match"
  fi

  case "$code" in
    *EXPIRED*|*expired*) soviez_update_die UPDATE_CAPABILITY_EXPIRED "product_updates entitlement expired" ;;
    *REVOKED*|*REFUND*|*DISPUTE*) soviez_update_die UPDATE_GRANT_REVOKED "Grant revoked/refunded/disputed" ;;
    *MONTHLY*) soviez_update_die UPDATE_MONTHLY_SUPPORT_DENIED "Monthly support denied for updates" ;;
    *UNBOUND*) soviez_update_die UPDATE_UNBOUND_GRANT_DENIED "Unbound grant denied" ;;
    *WRONG_LICENSE*) soviez_update_die UPDATE_WRONG_LICENSE "Wrong license" ;;
    *WRONG_ACCOUNT*) soviez_update_die UPDATE_WRONG_ACCOUNT "Wrong account" ;;
  esac

  if [[ "$allowed" != "true" && "$allowed" != "True" && "$decision" != "allow" ]]; then
    soviez_update_die UPDATE_CAPABILITY_REQUIRED "Active product_updates capability required for exact License"
  fi
  # Ensure capability name when present
  local caps
  caps="$(soviez_json_get "$ent_json" capability 2>/dev/null || true)"
  if [[ -n "$caps" && "$caps" != "null" && "$caps" != "product_updates" ]]; then
    soviez_update_die UPDATE_CAPABILITY_REQUIRED "Capability must be product_updates"
  fi
}
