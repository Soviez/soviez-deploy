# shellcheck shell=bash

soviez_device_private_key_file() {
  printf '%s/device-private-key\n' "${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
}

soviez_device_json_file() {
  printf '%s/device.json\n' "${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
}

# Prefer OpenSSL 3.x over macOS LibreSSL for ED25519.
soviez_openssl_bin() {
  if [[ -n "${SOVIEZ_OPENSSL:-}" && -x "${SOVIEZ_OPENSSL}" ]]; then
    printf '%s\n' "$SOVIEZ_OPENSSL"
    return 0
  fi
  local c
  for c in /opt/homebrew/bin/openssl /usr/local/opt/openssl@3/bin/openssl /usr/local/bin/openssl; do
    if [[ -x "$c" ]] && "$c" version 2>/dev/null | grep -qi 'OpenSSL'; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  command -v openssl
}

soviez_b64url() {
  "$(soviez_openssl_bin)" base64 -A | tr '+/' '-_' | tr -d '='
}

soviez_b64url_decode() {
  local in="$1"
  local pad=$(( (4 - ${#in} % 4) % 4 ))
  local padded="$in"
  while [[ $pad -gt 0 ]]; do padded="${padded}="; pad=$((pad - 1)); done
  printf '%s' "$padded" | tr '_-' '/+' | "$(soviez_openssl_bin)" base64 -d -A
}

soviez_sha256_hex() {
  printf '%s' "${1:-}" | "$(soviez_openssl_bin)" dgst -sha256 | awk '{print $NF}'
}

soviez_device_raw_pubkey_b64url() {
  local priv="$1"
  SOVIEZ_PRIV="$priv" SOVIEZ_OSSL="$(soviez_openssl_bin)" python3 - <<'PY'
import base64, subprocess, os
priv = os.environ["SOVIEZ_PRIV"]
ossl = os.environ["SOVIEZ_OSSL"]
pem = subprocess.check_output([ossl, "pkey", "-in", priv, "-pubout"], text=True)
body = "".join(line for line in pem.strip().splitlines() if not line.startswith("-----"))
raw = base64.b64decode(body)
key = raw[-32:]
print(base64.urlsafe_b64encode(key).decode().rstrip("="))
PY
}

soviez_device_fingerprint_from_raw_b64url() {
  local raw_b64="$1"
  local hex
  hex="$(printf '%s' "$(soviez_b64url_decode "$raw_b64")" | "$(soviez_openssl_bin)" dgst -sha256 | awk '{print $NF}')"
  local grouped
  grouped="$(printf '%s' "${hex:0:32}" | sed -E 's/(.{4})/\1:/g;s/:$//')"
  printf '%s\n' "$grouped"
}

soviez_device_ensure_keys() {
  local priv json dir ossl
  priv="$(soviez_device_private_key_file)"
  json="$(soviez_device_json_file)"
  dir="${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
  if [[ -f "$priv" ]]; then
    return 0
  fi
  mkdir -p "$dir"
  chmod 700 "$dir"
  ossl="$(soviez_openssl_bin)"
  "$ossl" genpkey -algorithm ED25519 -out "$priv" || return 1
  chmod 600 "$priv"

  local pub_raw_b64 fp
  pub_raw_b64="$(soviez_device_raw_pubkey_b64url "$priv")"
  fp="$(soviez_device_fingerprint_from_raw_b64url "$pub_raw_b64")"

  printf '{"public_key":"%s","public_key_fingerprint":"%s"}\n' "$pub_raw_b64" "$fp" > "$json"
  chmod 644 "$json"
}

soviez_device_public_key_b64url() {
  soviez_device_ensure_keys
  soviez_json_get "$(cat "$(soviez_device_json_file)")" "public_key"
}

soviez_device_fingerprint() {
  soviez_device_ensure_keys
  soviez_json_get "$(cat "$(soviez_device_json_file)")" "public_key_fingerprint"
}

soviez_device_sign_message() {
  local message="$1" ossl msgf sigf
  ossl="$(soviez_openssl_bin)"
  soviez_device_ensure_keys
  msgf="$(mktemp "${TMPDIR:-/tmp}/soviez-dsig-msg.XXXXXX")"
  sigf="$(mktemp "${TMPDIR:-/tmp}/soviez-dsig-out.XXXXXX")"
  printf '%s' "$message" > "$msgf"
  if ! "$ossl" pkeyutl -sign -inkey "$(soviez_device_private_key_file)" -rawin -in "$msgf" -out "$sigf" 2>/dev/null; then
    if ! printf '%s' "$message" | "$ossl" pkeyutl -sign -inkey "$(soviez_device_private_key_file)" -in /dev/stdin -out "$sigf" 2>/dev/null; then
      rm -f "$msgf" "$sigf"
      return 1
    fi
  fi
  "$ossl" base64 -A -in "$sigf" | tr '+/' '-_' | tr -d '='
  rm -f "$msgf" "$sigf"
}
