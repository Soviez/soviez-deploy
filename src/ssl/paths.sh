# shellcheck shell=bash
# Phase 12 SSL paths and inventory locations (local-first; no SaaS required).

soviez_ssl_paths_init() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    SOVIEZ_SSL_ROOT="$SOVIEZ_ROOT/ssl"
    SOVIEZ_SSL_INVENTORY_DIR="$SOVIEZ_SSL_ROOT/inventory"
    SOVIEZ_SSL_CERTS_DIR="$SOVIEZ_SSL_ROOT/certs"
    SOVIEZ_SSL_STAGING_DIR="$SOVIEZ_SSL_ROOT/staging"
    SOVIEZ_SSL_CHALLENGE_DIR="$SOVIEZ_SSL_ROOT/challenges"
    SOVIEZ_SSL_NGINX_OWNED_DIR="$SOVIEZ_SSL_ROOT/nginx-owned"
    SOVIEZ_SSL_OPS_DIR="$SOVIEZ_OPS_ROOT/ssl-operations"
  else
    _soviez_ssl_root="${SOVIEZ_ROOT:-/var/soviez}"
    _soviez_ssl_ops="${SOVIEZ_OPS_ROOT:-${_soviez_ssl_root}/ops}"
    SOVIEZ_SSL_ROOT="${SOVIEZ_SSL_ROOT:-${_soviez_ssl_root}/ssl}"
    SOVIEZ_SSL_INVENTORY_DIR="${SOVIEZ_SSL_INVENTORY_DIR:-$SOVIEZ_SSL_ROOT/inventory}"
    SOVIEZ_SSL_CERTS_DIR="${SOVIEZ_SSL_CERTS_DIR:-$SOVIEZ_SSL_ROOT/certs}"
    SOVIEZ_SSL_STAGING_DIR="${SOVIEZ_SSL_STAGING_DIR:-$SOVIEZ_SSL_ROOT/staging}"
    SOVIEZ_SSL_CHALLENGE_DIR="${SOVIEZ_SSL_CHALLENGE_DIR:-$SOVIEZ_SSL_ROOT/challenges}"
    SOVIEZ_SSL_NGINX_OWNED_DIR="${SOVIEZ_SSL_NGINX_OWNED_DIR:-$SOVIEZ_SSL_ROOT/nginx-owned}"
    SOVIEZ_SSL_OPS_DIR="${SOVIEZ_SSL_OPS_DIR:-${_soviez_ssl_ops}/ssl-operations}"
    unset _soviez_ssl_root _soviez_ssl_ops
  fi
  export SOVIEZ_SSL_ROOT SOVIEZ_SSL_INVENTORY_DIR SOVIEZ_SSL_CERTS_DIR
  export SOVIEZ_SSL_STAGING_DIR SOVIEZ_SSL_CHALLENGE_DIR SOVIEZ_SSL_NGINX_OWNED_DIR SOVIEZ_SSL_OPS_DIR
  mkdir -p "$SOVIEZ_SSL_INVENTORY_DIR" "$SOVIEZ_SSL_CERTS_DIR" "$SOVIEZ_SSL_STAGING_DIR" \
    "$SOVIEZ_SSL_CHALLENGE_DIR" "$SOVIEZ_SSL_NGINX_OWNED_DIR" "$SOVIEZ_SSL_OPS_DIR" 2>/dev/null || true
  chmod 700 "$SOVIEZ_SSL_ROOT" "$SOVIEZ_SSL_CERTS_DIR" "$SOVIEZ_SSL_STAGING_DIR" \
    "$SOVIEZ_SSL_CHALLENGE_DIR" "$SOVIEZ_SSL_INVENTORY_DIR" 2>/dev/null || true
}

soviez_ssl_inventory_file() {
  local env_id="$1"
  printf '%s/%s.json\n' "$SOVIEZ_SSL_INVENTORY_DIR" "$env_id"
}

soviez_ssl_env_cert_dir() {
  local env_id="$1"
  printf '%s/%s\n' "$SOVIEZ_SSL_CERTS_DIR" "$env_id"
}

soviez_ssl_lock_dir() {
  local env_id="$1"
  printf '%s/locks/%s\n' "$SOVIEZ_SSL_ROOT" "$env_id"
}
