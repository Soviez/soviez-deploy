#!/usr/bin/env bash
# shellcheck shell=bash
# Phase 18 — replace leaf self-signed with fixture CA-signed cert (trusted via local CA store).

soviez_migration_tls_fixture_ca_dir() {
  soviez_migration_paths_init
  printf '%s/tls_fixture_ca\n' "$SOVIEZ_MIG_SECRETS_DIR"
}

soviez_migration_tls_fixture_ensure_ca() {
  local ca_dir ca_key ca_crt
  ca_dir="$(soviez_migration_tls_fixture_ca_dir)"
  mkdir -p "$ca_dir"
  chmod 700 "$ca_dir"
  ca_key="$ca_dir/ca.key"
  ca_crt="$ca_dir/ca.crt"
  if [[ ! -f "$ca_crt" ]]; then
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -nodes \
      -keyout "$ca_key" -out "$ca_crt" -subj "/CN=soviez-migration-fixture-ca" 2>/dev/null \
      || soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "Fixture CA create failed"
    chmod 600 "$ca_key"
    chmod 644 "$ca_crt"
  fi
  printf '%s|%s\n' "$ca_crt" "$ca_key"
}

soviez_migration_tls_fixture_issue() {
  local pair_id="$1" fqdn="$2"
  local sec_dir cert key csr ca_paths ca_crt ca_key
  sec_dir="$(soviez_migration_tls_secrets_dir "$pair_id" "$fqdn")"
  mkdir -p "$sec_dir"
  chmod 700 "$sec_dir"
  cert="$sec_dir/fullchain.pem"
  key="$sec_dir/privkey.pem"
  csr="$sec_dir/req.csr"
  ca_paths="$(soviez_migration_tls_fixture_ensure_ca)"
  ca_crt="${ca_paths%%|*}"
  ca_key="${ca_paths#*|}"

  openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$key" -out "$csr" -subj "/CN=$fqdn" 2>/dev/null \
    || soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "CSR failed"
  openssl x509 -req -in "$csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial \
    -out "$sec_dir/cert.pem" -days 30 2>/dev/null \
    || soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "CA sign failed"
  cat "$sec_dir/cert.pem" "$ca_crt" > "$cert"
  chmod 600 "$key"
  chmod 644 "$cert"
  rm -f "$csr"
  # Trust store for verification
  cp "$ca_crt" "$sec_dir/trusted_ca.pem"
  printf '%s|%s\n' "$cert" "$key"
}

soviez_migration_tls_acme_issue() {
  local pair_id="$1" fqdn="$2"
  if [[ "${SOVIEZ_MIG_ACME_PEBBLE:-0}" == "1" ]]; then
    if declare -F soviez_migration_tls_pebble_issue >/dev/null 2>&1; then
      soviez_migration_tls_pebble_issue "$pair_id" "$fqdn"
      return $?
    fi
    soviez_migration_die MIGRATION_ACME_ORDER_FAILED "Pebble issuer not loaded"
  fi
  # Default disposable path: fixture public CA (not leaf self-signed)
  soviez_migration_tls_fixture_issue "$pair_id" "$fqdn"
}
