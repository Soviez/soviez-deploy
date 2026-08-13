# shellcheck shell=bash

soviez_migration_tls_verify_cert() {
  local cert_path="$1" fqdn="$2"
  local ca_path="${3:-}"
  [[ -f "$cert_path" ]] || soviez_migration_die MIGRATION_TLS_CHAIN_INVALID "Certificate missing"
  if ! openssl x509 -in "$cert_path" -noout >/dev/null 2>&1; then
    soviez_migration_die MIGRATION_TLS_CHAIN_INVALID "Certificate parse failed"
  fi

  # Hostname: CN or SAN DNS must match exact FQDN
  local cn san_ok=1
  cn="$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed -n 's/.*CN *= *\([^,/]*\).*/\1/p' | tr -d '[:space:]')"
  if [[ "$cn" != "$fqdn" ]]; then
    if openssl x509 -in "$cert_path" -noout -ext subjectAltName 2>/dev/null \
      | grep -qiE "DNS:${fqdn}(,|$| )"; then
      san_ok=0
    elif openssl x509 -in "$cert_path" -noout -text 2>/dev/null \
      | grep -qiE "DNS:${fqdn}(,|$| )"; then
      san_ok=0
    else
      soviez_migration_die MIGRATION_TLS_HOSTNAME_MISMATCH "Certificate CN/SAN mismatch"
    fi
  else
    san_ok=0
  fi
  [[ "$san_ok" -eq 0 ]]

  # Reject bare self-signed leaf (issuer == subject) unless explicitly allowed
  local subj iss
  subj="$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null)"
  iss="$(openssl x509 -in "$cert_path" -noout -issuer 2>/dev/null)"
  if [[ "$subj" == "$iss" && "${SOVIEZ_MIG_TLS_ALLOW_SELF_SIGNED:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_TLS_NOT_TRUSTED "Self-signed leaf certificate denied"
  fi

  if [[ -n "$ca_path" && -f "$ca_path" ]]; then
    if openssl verify -CAfile "$ca_path" "$cert_path" >/dev/null 2>&1; then
      return 0
    fi
    local issuer_path
    issuer_path="$(dirname "$cert_path")/issuer.pem"
    if [[ -f "$issuer_path" ]] \
      && openssl verify -CAfile "$ca_path" -untrusted "$issuer_path" "$cert_path" >/dev/null 2>&1; then
      return 0
    fi
    if [[ "${SOVIEZ_MIG_ACME_PEBBLE:-0}" == "1" ]] \
      && openssl verify -CAfile "$ca_path" -partial_chain "$cert_path" >/dev/null 2>&1; then
      return 0
    fi
    soviez_migration_die MIGRATION_TLS_CHAIN_INVALID "Chain verification failed"
  fi
  return 0
}
