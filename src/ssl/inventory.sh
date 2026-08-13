# shellcheck shell=bash
# Phase 12 certificate inventory (no private keys / secrets in records).

soviez_ssl_inventory_write_atomic() {
  local env_id="$1"
  local json="$2"
  local target tmp
  soviez_ssl_paths_init
  target="$(soviez_ssl_inventory_file "$env_id")"
  tmp="${target}.tmp.$$"
  printf '%s\n' "$json" > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$target"
}

soviez_ssl_inventory_read() {
  local env_id="$1"
  local f
  soviez_ssl_paths_init
  f="$(soviez_ssl_inventory_file "$env_id")"
  [[ -f "$f" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_NO_MANAGED_ENVIRONMENT" "No SSL inventory for $env_id"
  cat "$f"
}

soviez_ssl_inventory_exists() {
  local env_id="$1"
  soviez_ssl_paths_init
  [[ -f "$(soviez_ssl_inventory_file "$env_id")" ]]
}

soviez_ssl_inventory_create() {
  local env_id="$1"
  local env_type="$2"
  local domain="$3"
  local cert_path="$4"
  local key_path="$5"
  local chain_path="${6:-}"
  local cert_mode="${7:-public}"
  local provider="${8:-$SOVIEZ_SSL_DEFAULT_ACME_PROVIDER}"
  local renewal_mode="${9:-$SOVIEZ_SSL_DEFAULT_RENEWAL_MODE}"
  local wildcard_scope="${10:-}"
  local private_ca_flag="${11:-0}"

  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "environment id required"
  [[ -n "$domain" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_DOMAIN_REQUIRED" "domain required"
  renewal_mode="$(soviez_ssl_policy_normalize_mode "$renewal_mode")"
  soviez_ssl_policy_assert_ca "$cert_mode"

  local digest serial not_before not_after issuer
  digest=""
  serial=""
  not_before=""
  not_after=""
  issuer=""
  if [[ -f "$cert_path" ]]; then
    digest="$(openssl x509 -in "$cert_path" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//' | tr -d ':')"
    serial="$(openssl x509 -in "$cert_path" -noout -serial 2>/dev/null | sed 's/serial=//')"
    not_before="$(openssl x509 -in "$cert_path" -noout -startdate 2>/dev/null | sed 's/notBefore=//')"
    not_after="$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
    issuer="$(openssl x509 -in "$cert_path" -noout -issuer 2>/dev/null | sed 's/issuer=//')"
  fi

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local json
  json="$(ENV_ID="$env_id" ENV_TYPE="$env_type" DOMAIN="$domain" CERT="$cert_path" KEY="$key_path" \
    CHAIN="$chain_path" MODE="$cert_mode" PROVIDER="$provider" RMODE="$renewal_mode" \
    DIGEST="$digest" SERIAL="$serial" NB="$not_before" NA="$not_after" ISSUER="$issuer" \
    WS="$wildcard_scope" PCA="$private_ca_flag" NOW="$now" LEAD="$SOVIEZ_SSL_DEFAULT_RENEWAL_LEAD_DAYS" \
    python3 - <<'PY'
import json, os
rec = {
  "environment_id": os.environ["ENV_ID"],
  "environment_type": os.environ["ENV_TYPE"],
  "domain": os.environ["DOMAIN"],
  "certificate_mode": os.environ["MODE"],
  "acme_provider": os.environ["PROVIDER"],
  "certificate_path": os.environ["CERT"],
  "private_key_path": os.environ["KEY"],
  "chain_path": os.environ.get("CHAIN") or None,
  "issuer": os.environ.get("ISSUER") or None,
  "serial_abbreviated": (os.environ.get("SERIAL") or "")[:16] or None,
  "not_before": os.environ.get("NB") or None,
  "not_after": os.environ.get("NA") or None,
  "hostname_verification": None,
  "chain_verification": None,
  "current_certificate_digest": os.environ.get("DIGEST") or None,
  "previous_certificate_digest": None,
  "renewal_mode": os.environ["RMODE"],
  "renewal_lead_days": int(os.environ.get("LEAD") or "30"),
  "last_renewal_attempt": None,
  "last_successful_renewal": None,
  "next_scheduled_attempt": None,
  "retry_count": 0,
  "last_failure_code": None,
  "lifecycle_state": "healthy",
  "readiness_state": "ready" if os.environ["ENV_TYPE"].lower() != "production" else "ready",
  "operation_id": None,
  "challenge_id": None,
  "wildcard_scope": os.environ.get("WS") or None,
  "private_ca_policy": os.environ.get("PCA") == "1",
  "created_at": os.environ["NOW"],
  "updated_at": os.environ["NOW"],
}
# Never embed key material
assert "BEGIN" not in json.dumps(rec)
print(json.dumps(rec, indent=2))
PY
)"
  soviez_ssl_inventory_write_atomic "$env_id" "$json"
}

soviez_ssl_inventory_patch() {
  local env_id="$1"
  local patch_json="$2"
  local current
  current="$(soviez_ssl_inventory_read "$env_id")"
  local merged
  merged="$(CUR="$current" PATCH="$patch_json" python3 - <<'PY'
import json, os, time
cur = json.loads(os.environ["CUR"])
patch = json.loads(os.environ["PATCH"])
# Forbid secret-like keys
for k in list(patch.keys()):
    if k.lower() in ("private_key", "private_key_pem", "acme_account_key", "token", "secret"):
        raise SystemExit("secret fields forbidden in inventory patch")
cur.update(patch)
cur["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
print(json.dumps(cur, indent=2))
PY
)"
  soviez_ssl_inventory_write_atomic "$env_id" "$merged"
}

soviez_ssl_inventory_list_ids() {
  soviez_ssl_paths_init
  local f
  for f in "$SOVIEZ_SSL_INVENTORY_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    basename "$f" .json
  done
}

soviez_ssl_inventory_validate_record() {
  local env_id="$1"
  local rec cert key
  rec="$(soviez_ssl_inventory_read "$env_id")"
  cert="$(soviez_json_get "$rec" certificate_path)"
  key="$(soviez_json_get "$rec" private_key_path)"
  local domain id_in_rec
  domain="$(soviez_json_get "$rec" domain)"
  id_in_rec="$(soviez_json_get "$rec" environment_id)"
  [[ "$id_in_rec" == "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_IDENTITY_MISMATCH" "inventory id mismatch"
  [[ -n "$domain" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_DOMAIN_REQUIRED" "domain missing in inventory"
  [[ -f "$cert" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_MISSING" "certificate file missing"
  [[ -f "$key" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_MISSING" "private key file missing"
}
