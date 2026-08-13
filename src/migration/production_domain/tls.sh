# shellcheck shell=bash
# Phase 21 Production TLS gate. Fixture mode writes a disposable, real
# (openssl-issued) cert/key pair for the exact Production FQDN so hostname
# verification is meaningful without requiring live ACME/DNS.

soviez_migration_p21_tls_dir() {
  local auth_id="$1"
  printf '%s/activation/%s/certs\n' "$SOVIEZ_MIG_ROOT" "$auth_id"
}

soviez_migration_p21_tls_prepare_fixture() {
  local auth_id="${1:-}" fqdn="${2:-}"
  [[ -n "$auth_id" && -n "$fqdn" ]] || soviez_migration_die MIGRATION_TLS_PRODUCTION_INVALID "auth-id and fqdn required"
  local dir
  dir="$(soviez_migration_p21_tls_dir "$auth_id")"
  mkdir -p "$dir/ca"
  if [[ ! -f "$dir/cert.pem" || ! -f "$dir/key.pem" ]]; then
    # Local disposable CA → leaf (not a bare self-signed Production leaf).
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -nodes \
      -keyout "$dir/ca/ca.key" -out "$dir/ca/ca.pem" -subj "/CN=Soviez-P21-Disposable-CA" >/dev/null 2>&1
    openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
      -keyout "$dir/key.pem" -out "$dir/req.csr" -subj "/CN=$fqdn" >/dev/null 2>&1
    cat > "$dir/ext.cnf" <<EOF
basicConstraints=CA:FALSE
subjectAltName=DNS:${fqdn}
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF
    openssl x509 -req -in "$dir/req.csr" -CA "$dir/ca/ca.pem" -CAkey "$dir/ca/ca.key" -CAcreateserial \
      -out "$dir/cert.pem" -days 30 -extfile "$dir/ext.cnf" >/dev/null 2>&1
    cat "$dir/cert.pem" "$dir/ca/ca.pem" > "$dir/fullchain.pem"
    chmod 600 "$dir/key.pem" "$dir/ca/ca.key" 2>/dev/null || true
    rm -f "$dir/req.csr" "$dir/ext.cnf"
  fi
  # Chain validation against local CA
  openssl verify -CAfile "$dir/ca/ca.pem" "$dir/cert.pem" >/dev/null 2>&1 || \
    soviez_migration_die MIGRATION_PRODUCTION_TLS_INVALID "certificate chain validation failed"
  printf '%s|%s\n' "$dir/fullchain.pem" "$dir/key.pem"
}

soviez_migration_p21_tls_validate() {
  local auth_id="${1:-}" fqdn="${2:-}"
  [[ -n "$auth_id" && -n "$fqdn" ]] || soviez_migration_die MIGRATION_TLS_PRODUCTION_INVALID "auth-id and fqdn required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_TLS_VALIDATE"

  local dir cert key
  dir="$(soviez_migration_p21_tls_dir "$auth_id")"
  cert="$dir/cert.pem"; key="$dir/key.pem"

  if [[ "${SOVIEZ_MIG_P21_REQUIRE_REAL_TLS:-0}" == "1" ]]; then
    [[ -f "$cert" ]] || soviez_migration_die MIGRATION_TLS_PRODUCTION_INVALID "production certificate missing"
  elif [[ ! -f "$cert" ]]; then
    soviez_migration_p21_tls_prepare_fixture "$auth_id" "$fqdn" >/dev/null
  fi

  soviez_migration_tls_verify_cert "$cert" "$fqdn"

  local not_after
  not_after="$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
  if [[ -n "$not_after" ]]; then
    local exp_epoch now_epoch
    exp_epoch="$(date -u -j -f '%b %e %T %Y %Z' "$not_after" +%s 2>/dev/null || date -u -d "$not_after" +%s 2>/dev/null || echo 0)"
    now_epoch="$(soviez_migration_now_epoch)"
    if [[ "$exp_epoch" -gt 0 && $((exp_epoch - now_epoch)) -lt 86400 ]]; then
      soviez_migration_die MIGRATION_TLS_PRODUCTION_EXPIRED "production certificate expires within 24h"
    fi
  fi

  printf '{"fqdn":"%s","certificate_path":"%s","key_path":"%s","valid":true,"not_after":"%s"}\n' \
    "$fqdn" "$cert" "$key" "$not_after"
}
