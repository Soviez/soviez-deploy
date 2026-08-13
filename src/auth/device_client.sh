# shellcheck shell=bash

soviez_device_credential_file() {
  printf '%s/credential.json\n' "${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
}

soviez_device_client_start() {
  soviez_device_ensure_keys
  local pub fp nonce body resp
  pub="$(soviez_device_public_key_b64url)"
  fp="$(soviez_device_fingerprint)"
  nonce="$(openssl rand -hex 8)"
  body="$(SOVIEZ_JSON_PUB="$pub" SOVIEZ_JSON_FP="$fp" SOVIEZ_JSON_NONCE="$nonce" python3 - <<'PY'
import json, os
print(json.dumps({
    "public_key": os.environ["SOVIEZ_JSON_PUB"],
    "public_key_fingerprint": os.environ["SOVIEZ_JSON_FP"],
    "display_label": os.environ.get("SOVIEZ_DEVICE_LABEL", "soviez-installer"),
    "protocol_version": "device-auth/v1",
    "nonce": os.environ["SOVIEZ_JSON_NONCE"],
}, separators=(",", ":")))
PY
)"
  resp="$(soviez_http_post_json "$SOVIEZ_SAAS_BASE_URL/api/installer-auth/device/start" "$body")"
  printf '%s' "$resp"
}

soviez_device_client_poll_token() {
  local device_code="$1"
  local proof_nonce sig body resp
  proof_nonce="$(openssl rand -hex 8)"
  sig="$(soviez_signing_sign_token_proof "$device_code" "$proof_nonce")"
  body="$(SOVIEZ_JSON_CODE="$device_code" SOVIEZ_JSON_SIG="$sig" SOVIEZ_JSON_NONCE="$proof_nonce" python3 - <<'PY'
import json, os
print(json.dumps({
    "device_code": os.environ["SOVIEZ_JSON_CODE"],
    "proof_signature": os.environ["SOVIEZ_JSON_SIG"],
    "proof_nonce": os.environ["SOVIEZ_JSON_NONCE"],
}, separators=(",", ":")))
PY
)"
  resp="$(soviez_http_post_json "$SOVIEZ_SAAS_BASE_URL/api/installer-auth/device/token" "$body")"
  printf '%s' "$resp"
}

soviez_device_client_store_credential() {
  local json="$1"
  local dir cred
  dir="${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
  cred="$(soviez_device_credential_file)"
  mkdir -p "$dir"
  chmod 700 "$dir"
  printf '%s\n' "$json" > "$cred"
  chmod 600 "$cred"
}

soviez_device_client_load_credential() {
  local cred
  cred="$(soviez_device_credential_file)"
  if [[ ! -f "$cred" ]]; then
    return 1
  fi
  cat "$cred"
}

soviez_device_client_authorize() {
  local start_json="$1"
  local device_code interval
  device_code="$(soviez_json_get "$start_json" "device_code")"
  interval="$(soviez_json_get "$start_json" "interval")"
  [[ -z "$interval" ]] && interval=1

  local attempt=0
  while [[ $attempt -lt 30 ]]; do
    local token_json err
    token_json="$(soviez_device_client_poll_token "$device_code")"
    err="$(soviez_json_get "$token_json" "error" 2>/dev/null || true)"
    case "$err" in
      authorization_pending|slow_down|"")
        if [[ -z "$err" ]] && soviez_json_get "$token_json" "device_id" >/dev/null 2>&1; then
          soviez_device_client_store_credential "$token_json"
          printf '%s' "$token_json"
          return 0
        fi
        sleep "$interval"
        attempt=$((attempt + 1))
        ;;
      access_denied|expired_token|invalid_grant)
        soviez_die "$SOVIEZ_ERR_AUTH" "Device authorization failed: $err"
        ;;
      *)
        sleep "$interval"
        attempt=$((attempt + 1))
        ;;
    esac
  done
  soviez_die "$SOVIEZ_ERR_AUTH" "Device authorization timed out"
}
