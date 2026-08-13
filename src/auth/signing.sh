# shellcheck shell=bash

SOVIEZ_DEVICE_AUTH_PROTOCOL="device-auth/v1"
SOVIEZ_DEVICE_AUTH_DOMAIN="soviez.device-auth.v1"

soviez_signing_canonicalize_path() {
  local path="$1"
  [[ "$path" == /* ]] || path="/$path"
  path="${path%%\?*}"
  path="${path%%#*}"
  printf '%s' "$path"
}

soviez_signing_body_hash() {
  local body="${1:-}"
  soviez_sha256_hex "$body"
}

soviez_signing_build_canonical() {
  local method="$1"
  local path="$2"
  local timestamp="$3"
  local nonce="$4"
  local body="${5:-}"
  local device_id="$6"
  local credential_id="$7"

  method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
  path="$(soviez_signing_canonicalize_path "$path")"
  local body_hash
  body_hash="$(soviez_signing_body_hash "$body")"

  printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' \
    "$SOVIEZ_DEVICE_AUTH_PROTOCOL" \
    "$method" \
    "$path" \
    "$timestamp" \
    "$nonce" \
    "$body_hash" \
    "$device_id" \
    "$credential_id"
}

soviez_signing_with_domain() {
  local canonical="$1"
  printf '%s\n%s' "$SOVIEZ_DEVICE_AUTH_DOMAIN" "$canonical"
}

soviez_signing_sign_request() {
  local method="$1"
  local path="$2"
  local timestamp="$3"
  local nonce="$4"
  local body="${5:-}"
  local device_id="$6"
  local credential_id="$7"

  local canonical domain sig
  canonical="$(soviez_signing_build_canonical "$method" "$path" "$timestamp" "$nonce" "$body" "$device_id" "$credential_id")"
  domain="$(soviez_signing_with_domain "$canonical")"
  sig="$(soviez_device_sign_message "$domain")"
  printf '%s' "$sig"
}

soviez_signing_build_token_proof() {
  local device_code="$1"
  local nonce="$2"
  soviez_signing_with_domain "$(printf 'token-proof\n%s\n%s\n%s' "$SOVIEZ_DEVICE_AUTH_PROTOCOL" "$device_code" "$nonce")"
}

soviez_signing_sign_token_proof() {
  local device_code="$1"
  local nonce="$2"
  local msg
  msg="$(soviez_signing_build_token_proof "$device_code" "$nonce")"
  soviez_device_sign_message "$msg"
}
