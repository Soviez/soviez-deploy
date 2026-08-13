# shellcheck shell=bash

soviez_migration_landing_write_nginx() {
  local site_dir="$1" migration_fqdn="$2" cert="${3:-}" key="${4:-}"
  local ssl_block listen443=""
  if [[ -n "$cert" && -n "$key" ]]; then
    listen443="
    listen 443 ssl;
    ssl_certificate ${cert};
    ssl_certificate_key ${key};"
  fi
  cat > "$site_dir/nginx.conf" <<EOF
# SOVIEZ_OWNED module=migration_landing version=phase18
server {
    listen 80;
    server_name ${migration_fqdn};
    root ${site_dir}/www;
    location /healthz {
        default_type application/json;
        try_files /healthz =404;
    }
    location / {
        try_files /index.html =404;
    }
$(soviez_migration_landing_security_headers_block)
}
EOF
  if [[ -n "$cert" && -n "$key" ]]; then
    cat >> "$site_dir/nginx.conf" <<EOF
server {${listen443}
    server_name ${migration_fqdn};
    root ${site_dir}/www;
    location /healthz {
        default_type application/json;
        try_files /healthz =404;
    }
    location / {
        try_files /index.html =404;
    }
$(soviez_migration_landing_security_headers_block)
}
EOF
  fi
}

soviez_migration_landing_validate_nginx() {
  local conf="$1" migration_fqdn="$2" production_fqdn="$3"
  [[ -f "$conf" ]] || soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "Missing nginx config"
  if grep -q "server_name[[:space:]]*${production_fqdn}[;[:space:]]" "$conf" 2>/dev/null; then
    soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "Production domain must not appear in server_name"
  fi
  if ! grep -q "server_name[[:space:]]*${migration_fqdn}[;[:space:]]" "$conf"; then
    soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "Migration FQDN missing from server_name"
  fi
  if [[ "${SOVIEZ_MIG_LANDING_REAL_NGINX:-0}" == "1" ]] && command -v docker >/dev/null 2>&1; then
    docker run --rm -v "$conf:/etc/nginx/conf.d/default.conf:ro" nginx:alpine nginx -t >/dev/null 2>&1 || \
      soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "docker nginx -t failed"
    return 0
  fi
  if declare -F soviez_nginx_test_config >/dev/null 2>&1; then
    soviez_nginx_test_config "$conf" || soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "nginx config test failed"
  else
    grep -q 'server_name' "$conf" || soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "invalid nginx structure"
  fi
}
