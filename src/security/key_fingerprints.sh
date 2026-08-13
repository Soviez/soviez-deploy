# shellcheck shell=bash
# Phase 24 — public key fingerprint / secret hygiene helpers.

soviez_security_pubkey_fingerprint() {
  local pem_file="$1"
  [[ -f "$pem_file" ]] || return 1
  # SHA-256 of canonical DER/SPKI when openssl available; else of PEM body bytes.
  if command -v openssl >/dev/null 2>&1; then
    openssl pkey -pubin -in "$pem_file" -outform DER 2>/dev/null | shasum -a 256 | awk '{print "sha256:"$1}'
    return 0
  fi
  shasum -a 256 "$pem_file" | awk '{print "sha256:"$1}'
}

soviez_security_secret_fingerprint() {
  local value="$1"
  printf '%s' "$value" | shasum -a 256 | awk '{print "sha256:"$1}'
}

soviez_security_assert_private_key_perms() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  local mode
  mode="$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path" 2>/dev/null || echo 777)"
  if [[ "$mode" != "600" && "$mode" != "400" ]]; then
    soviez_security_die SECURITY_PRIVATE_KEY_EXPOSED "insecure private key mode=$mode path=$(basename "$path")"
  fi
  return 0
}

# Write secret with fingerprint sidecar (plaintext remains 0600; fingerprint for audit/compare).
soviez_security_secret_write_hygienic() {
  local name="$1" value="$2"
  if declare -F soviez_tenant_secret_write >/dev/null 2>&1; then
    soviez_tenant_secret_write "$name" "$value"
  else
    return 1
  fi
  local fp path
  fp="$(soviez_security_secret_fingerprint "$value")"
  path="$(soviez_tenant_secret_path "$name").sha256"
  umask 077
  printf '%s\n' "$fp" > "$path"
  chmod 600 "$path"
}
