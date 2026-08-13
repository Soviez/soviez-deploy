# shellcheck shell=bash
# Phase 12 ACME provider abstraction (default Let's Encrypt; fixture for isolated tests).

soviez_ssl_provider_id() {
  printf '%s\n' "${SOVIEZ_SSL_ACME_PROVIDER:-$SOVIEZ_SSL_DEFAULT_ACME_PROVIDER}"
}

soviez_ssl_provider_issue() {
  local provider="$1"
  local domain="$2"
  local out_cert="$3"
  local out_key="$4"
  local out_chain="$5"
  case "$provider" in
    fixture|local_ca|test)
      # Isolated trusted local CA — NOT self-signed leaf without CA.
      local work lines cert key ca
      work="$(mktemp -d "${TMPDIR:-/tmp}/soviez-issue.XXXXXX")"
      lines="$(soviez_ssl_local_issue_fresh "$domain" "$work")"
      cert="$(printf '%s\n' "$lines" | sed -n '1p')"
      key="$(printf '%s\n' "$lines" | sed -n '2p')"
      ca="$(printf '%s\n' "$lines" | sed -n '3p')"
      mkdir -p "$(dirname "$out_cert")"
      cp -f "$cert" "$out_cert"
      cp -f "$key" "$out_key"
      cp -f "$ca" "$out_chain"
      chmod 644 "$out_cert" "$out_chain"
      chmod 600 "$out_key"
      rm -rf "$work"
      ;;
    letsencrypt)
      if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
        # In test mode never call public ACME — use fixture path.
        soviez_ssl_provider_issue fixture "$domain" "$out_cert" "$out_key" "$out_chain"
        return 0
      fi
      # Production path: render certbot contract (actual issuance deferred to host tooling).
      local email="${SOVIEZ_SSL_ACME_EMAIL:-admin@localhost}"
      soviez_ssl_letsencrypt_render "$domain" "$email" > "$(dirname "$out_cert")/certbot.cmd"
      soviez_ssl_die "$SOVIEZ_SSL_CODE_ACME_PROVIDER_UNAVAILABLE" \
        "Let's Encrypt issuance requires certbot on host; use fixture provider in tests"
      ;;
    *)
      soviez_ssl_die "$SOVIEZ_SSL_CODE_ACME_PROVIDER_UNAVAILABLE" "Unknown ACME provider: $provider"
      ;;
  esac
}

# Always issue a fresh cert (bypass local_ca cache) for renewal tests.
soviez_ssl_local_issue_fresh() {
  local domain="$1"
  local cert_dir="$2"
  local ca_dir="$SOVIEZ_ROOT/ssl/local-ca"
  mkdir -p "$cert_dir" "$ca_dir"
  chmod 700 "$cert_dir"
  if [[ ! -f "$ca_dir/ca.crt" ]]; then
    soviez_ssl_local_ca_init >/dev/null
  fi
  openssl genrsa -out "$cert_dir/server.key" 2048 >/dev/null 2>&1
  chmod 600 "$cert_dir/server.key"
  # SAN for hostname match
  printf 'subjectAltName=DNS:%s\n' "$domain" > "$cert_dir/ext.cnf"
  openssl req -new -key "$cert_dir/server.key" -subj "/CN=$domain" -out "$cert_dir/server.csr" >/dev/null 2>&1
  openssl x509 -req -in "$cert_dir/server.csr" -CA "$ca_dir/ca.crt" -CAkey "$ca_dir/ca.key" \
    -CAcreateserial -out "$cert_dir/server.crt" -days 825 -sha256 -extfile "$cert_dir/ext.cnf" >/dev/null 2>&1
  printf '%s\n' "$cert_dir/server.crt" "$cert_dir/server.key" "$ca_dir/ca.crt"
}

soviez_ssl_provider_normalize_error() {
  local provider="$1"
  local stderr="$2"
  case "$stderr" in
    *rate*limit*|*ratelimit*|*too*many*)
      printf '%s\n' "$SOVIEZ_SSL_CODE_ACME_RATE_LIMITED"
      ;;
    *dns*)
      printf '%s\n' "$SOVIEZ_SSL_CODE_DNS_VALIDATION_FAILED"
      ;;
    *)
      if [[ "$provider" == "letsencrypt" ]]; then
        soviez_ssl_letsencrypt_map_error "$stderr"
      else
        printf '%s\n' "$SOVIEZ_SSL_CODE_RENEWAL_FAILED"
      fi
      ;;
  esac
}
