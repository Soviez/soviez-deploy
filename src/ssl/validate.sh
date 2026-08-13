# shellcheck shell=bash

soviez_ssl_validate_chain() {
  local cert_file="$1"
  local ca_file="${2:-}"

  if [[ ! -f "$cert_file" ]]; then
    if declare -F soviez_ssl_die >/dev/null 2>&1; then
      soviez_ssl_die "${SOVIEZ_SSL_CODE_CERTIFICATE_MISSING:-CERTIFICATE_MISSING}" "Certificate file missing"
    fi
    soviez_die "$SOVIEZ_ERR_SSL" "Certificate file missing"
  fi

  if [[ -n "$ca_file" && -f "$ca_file" ]]; then
    if openssl verify -CAfile "$ca_file" "$cert_file" >/dev/null 2>&1; then
      return 0
    fi
    if declare -F soviez_ssl_die >/dev/null 2>&1; then
      soviez_ssl_die "${SOVIEZ_SSL_CODE_CERTIFICATE_CHAIN_INVALID:-CERTIFICATE_CHAIN_INVALID}" "Certificate chain validation failed"
    fi
    soviez_die "$SOVIEZ_ERR_SSL" "Certificate chain validation failed"
  fi

  # Reject bare self-signed (issuer == subject) when no trusted CA provided.
  local issuer subject
  issuer="$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/^issuer=//')"
  subject="$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/^subject=//')"
  issuer="$(printf '%s' "$issuer" | tr -d ' ')"
  subject="$(printf '%s' "$subject" | tr -d ' ')"
  if [[ "$issuer" == "$subject" ]]; then
    if declare -F soviez_ssl_die >/dev/null 2>&1; then
      soviez_ssl_die "${SOVIEZ_SSL_CODE_SELF_SIGNED_NOT_ALLOWED:-SELF_SIGNED_NOT_ALLOWED}" "Self-signed certificate rejected"
    fi
    soviez_die "$SOVIEZ_ERR_SSL" "Self-signed certificate rejected"
  fi
  return 0
}

# Final acceptance helper — never allows self-signed or unapproved private CA.
soviez_ssl_final_acceptance() {
  local cert_file="$1"
  local ca_file="${2:-}"
  local cert_mode="${3:-public}"
  if declare -F soviez_ssl_policy_assert_ca >/dev/null 2>&1; then
    soviez_ssl_policy_assert_ca "$cert_mode"
  fi
  soviez_ssl_validate_chain "$cert_file" "$ca_file"
}
