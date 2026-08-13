# shellcheck shell=bash

soviez_http_post_json() {
  local url="$1"
  local body="${2:-}"
  local headers=(-H "Content-Type: application/json" -H "Accept: application/json")
  local resp code
  code="$(curl -sS -o /tmp/soviez_http_body.$$ -w '%{http_code}' "${headers[@]}" -X POST -d "$body" "$url" || echo "000")"
  resp="$(cat /tmp/soviez_http_body.$$ 2>/dev/null || true)"
  rm -f /tmp/soviez_http_body.$$
  if [[ "$code" -ge 400 || "$code" == "000" ]]; then
    soviez_log_error "HTTP POST failed url=$(soviez_redact_text "$url") code=$code body=$(soviez_redact_text "$resp")"
    soviez_die "$SOVIEZ_ERR_API" "HTTP request failed ($code)"
  fi
  if ! soviez_assert_no_secret_in_text "$resp" "http response"; then
    soviez_die "$SOVIEZ_ERR_API" "HTTP response leaked secret material"
  fi
  printf '%s' "$resp"
}

soviez_http_signed_post_json() {
  local path="$1"
  local body="${2:-}"
  local cred_json
  cred_json="$(soviez_device_client_load_credential)" || soviez_die "$SOVIEZ_ERR_AUTH" "Missing device credential"

  local device_id credential_id credential timestamp nonce signature
  device_id="$(soviez_json_get "$cred_json" "device_id")"
  credential_id="$(soviez_json_get "$cred_json" "credential_id")"
  credential="$(soviez_json_get "$cred_json" "credential")"
  timestamp="$(date +%s)"
  nonce="$(openssl rand -hex 12)"
  signature="$(soviez_signing_sign_request POST "$path" "$timestamp" "$nonce" "$body" "$device_id" "$credential_id")"

  local url="${SOVIEZ_SAAS_BASE_URL}${path}"
  local resp code
  code="$(curl -sS -o /tmp/soviez_http_body.$$ -w '%{http_code}' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Soviez-Device-Id: $device_id" \
    -H "X-Soviez-Credential-Id: $credential_id" \
    -H "X-Soviez-Credential: $credential" \
    -H "X-Soviez-Timestamp: $timestamp" \
    -H "X-Soviez-Nonce: $nonce" \
    -H "X-Soviez-Signature: $signature" \
    -X POST -d "$body" "$url" || echo "000")"
  resp="$(cat /tmp/soviez_http_body.$$ 2>/dev/null || true)"
  rm -f /tmp/soviez_http_body.$$
  soviez_log_debug "Signed POST path=$path code=$code"
  if [[ "$code" -ge 400 || "$code" == "000" ]]; then
    soviez_log_error "Signed HTTP failed path=$path code=$code body=$(soviez_redact_text "$resp")"
    soviez_die "$SOVIEZ_ERR_API" "Signed HTTP request failed ($code)"
  fi
  if ! soviez_assert_no_secret_in_text "$resp" "signed http response"; then
    soviez_die "$SOVIEZ_ERR_API" "Signed HTTP response leaked secret material"
  fi
  printf '%s' "$resp"
}

# Soft signed POST — logs failures but never aborts (optional complete/revoke).
soviez_http_signed_post_json_soft() {
  local path="$1"
  local body="${2:-}"
  local cred_json
  if ! cred_json="$(soviez_device_client_load_credential 2>/dev/null)"; then
    if declare -F soviez_log_warn >/dev/null 2>&1; then
      soviez_log_warn "Soft signed POST skipped (no device credential) path=$path"
    fi
    return 0
  fi

  local device_id credential_id credential timestamp nonce signature
  device_id="$(soviez_json_get "$cred_json" "device_id")"
  credential_id="$(soviez_json_get "$cred_json" "credential_id")"
  credential="$(soviez_json_get "$cred_json" "credential")"
  timestamp="$(date +%s)"
  nonce="$(openssl rand -hex 12)"
  signature="$(soviez_signing_sign_request POST "$path" "$timestamp" "$nonce" "$body" "$device_id" "$credential_id")"

  local url="${SOVIEZ_SAAS_BASE_URL}${path}"
  local resp code
  code="$(curl -sS -o /tmp/soviez_http_body.$$ -w '%{http_code}' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Soviez-Device-Id: $device_id" \
    -H "X-Soviez-Credential-Id: $credential_id" \
    -H "X-Soviez-Credential: $credential" \
    -H "X-Soviez-Timestamp: $timestamp" \
    -H "X-Soviez-Nonce: $nonce" \
    -H "X-Soviez-Signature: $signature" \
    -X POST -d "$body" "$url" || echo "000")"
  resp="$(cat /tmp/soviez_http_body.$$ 2>/dev/null || true)"
  rm -f /tmp/soviez_http_body.$$
  if [[ "$code" -ge 400 || "$code" == "000" ]]; then
    if declare -F soviez_log_warn >/dev/null 2>&1; then
      soviez_log_warn "Soft signed POST failed path=$path code=$code (non-fatal)"
    fi
    return 0
  fi
  printf '%s' "$resp"
  return 0
}
