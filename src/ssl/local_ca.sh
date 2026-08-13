# shellcheck shell=bash

soviez_ssl_local_ca_init() {
  local ca_dir="$SOVIEZ_ROOT/ssl/local-ca"
  mkdir -p "$ca_dir"
  chmod 700 "$ca_dir"
  if [[ ! -f "$ca_dir/ca.key" ]]; then
    openssl genrsa -out "$ca_dir/ca.key" 4096 >/dev/null 2>&1
    chmod 600 "$ca_dir/ca.key"
    openssl req -x509 -new -nodes -key "$ca_dir/ca.key" -sha256 -days 3650 \
      -subj "/CN=Soviez Local Test CA" -out "$ca_dir/ca.crt" >/dev/null 2>&1
  fi
  printf '%s\n' "$ca_dir/ca.crt" "$ca_dir/ca.key"
}

soviez_ssl_local_issue_cert() {
  local domain="$1"
  local ca_dir="$SOVIEZ_ROOT/ssl/local-ca"
  local cert_dir="$SOVIEZ_ROOT/ssl/certs/$domain"
  mkdir -p "$cert_dir"
  chmod 700 "$cert_dir"
  if [[ ! -f "$ca_dir/ca.crt" ]]; then
    soviez_ssl_local_ca_init >/dev/null
  fi
  if [[ ! -f "$cert_dir/server.key" ]]; then
    openssl genrsa -out "$cert_dir/server.key" 2048 >/dev/null 2>&1
    chmod 600 "$cert_dir/server.key"
    openssl req -new -key "$cert_dir/server.key" -subj "/CN=$domain" -out "$cert_dir/server.csr" >/dev/null 2>&1
    openssl x509 -req -in "$cert_dir/server.csr" -CA "$ca_dir/ca.crt" -CAkey "$ca_dir/ca.key" \
      -CAcreateserial -out "$cert_dir/server.crt" -days 825 -sha256 >/dev/null 2>&1
  fi
  printf '%s\n' "$cert_dir/server.crt" "$cert_dir/server.key" "$ca_dir/ca.crt"
}
