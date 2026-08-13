# shellcheck shell=bash
# Phase 21 nginx ownership — activates the destination Production route
# (previously disabled per Phase 18 routing template) and writes the source
# maintenance site. No wildcard server_name is ever permitted.

soviez_migration_p21_nginx_root() {
  printf '%s\n' "${SOVIEZ_MIG_P21_NGINX_ROOT:-${SOVIEZ_ROOT:-/var/soviez}/nginx_sites_p21}"
}

soviez_migration_p21_nginx_validate_no_wildcard() {
  local conf="$1"
  [[ -f "$conf" ]] || soviez_migration_die MIGRATION_NGINX_CONFIG_INVALID "nginx config missing"
  if grep -qE 'server_name[[:space:]]+\*' "$conf" 2>/dev/null; then
    soviez_migration_die MIGRATION_WILDCARD_ROUTE_FORBIDDEN "wildcard server_name forbidden"
  fi
}

# Resolve host-side loopback upstream for destination ERP HTTP (container :8069).
# Priority: explicit arg / SOVIEZ_MIG_P21_UPSTREAM / SOVIEZ_HOST_PORT / docker publish / 127.0.0.1:8069
soviez_migration_p21_resolve_upstream() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  if [[ -n "${SOVIEZ_MIG_P21_UPSTREAM:-}" ]]; then
    printf '%s\n' "$SOVIEZ_MIG_P21_UPSTREAM"
    return 0
  fi
  if [[ -n "${SOVIEZ_HOST_PORT:-}" ]]; then
    printf '127.0.0.1:%s\n' "$SOVIEZ_HOST_PORT"
    return 0
  fi
  local cname pub
  cname="${SOVIEZ_WEB_CONTAINER:-${SOVIEZ_MIG_P21_WEB_CONTAINER:-}}"
  if [[ -n "$cname" ]] && command -v docker >/dev/null 2>&1; then
    pub="$(docker port "$cname" 8069/tcp 2>/dev/null | head -1 | awk -F: '{print $NF}' || true)"
    if [[ -n "$pub" ]]; then
      printf '127.0.0.1:%s\n' "$pub"
      return 0
    fi
  fi
  # Fallback: destination contracted to publish ERP HTTP on loopback 8069
  printf '127.0.0.1:8069\n'
}

# soviez_migration_p21_nginx_activate_production <fqdn> <cert> <key> [upstream]
# Enables the destination ERP route (Phase 18 shipped it disabled).
soviez_migration_p21_nginx_activate_production() {
  local fqdn="${1:-}" cert="${2:-}" key="${3:-}" upstream_in="${4:-}"
  [[ -n "$fqdn" && -f "$cert" && -f "$key" ]] || \
    soviez_migration_die MIGRATION_DESTINATION_ROUTE_ACTIVATE_FAILED "fqdn/cert/key required"
  local upstream
  upstream="$(soviez_migration_p21_resolve_upstream "$upstream_in")"
  local root site conf
  root="$(soviez_migration_p21_nginx_root)"
  site="$root/destination"
  mkdir -p "$site"
  conf="$site/production.conf"
  cat > "$conf" <<EOF
# SOVIEZ_OWNED module=migration_cutover version=phase21-ws1
# upstream=${upstream} (host loopback → container HTTP 8069; not a public bind)
upstream soviez_p21_erp {
    server ${upstream};
}
server {
    listen 443 ssl;
    server_name ${fqdn};
    ssl_certificate ${cert};
    ssl_certificate_key ${key};
    proxy_read_timeout 720s;
    location /healthz {
        default_type application/json;
        return 200 '{"ok":true}';
    }
    location /websocket {
        proxy_pass http://soviez_p21_erp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }
    location /longpolling {
        proxy_pass http://soviez_p21_erp;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }
    location / {
        proxy_pass http://soviez_p21_erp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  soviez_migration_p21_nginx_validate_no_wildcard "$conf"
  rm -f "$site/production.conf.disabled"
  printf '%s\n' "$conf"
}

soviez_migration_p21_nginx_disable_production() {
  local root site conf
  root="$(soviez_migration_p21_nginx_root)"
  site="$root/destination"
  conf="$site/production.conf"
  [[ -f "$conf" ]] && mv "$conf" "$conf.disabled"
  return 0
}

# soviez_migration_p21_nginx_source_maintenance <fqdn>
soviez_migration_p21_nginx_source_maintenance() {
  local fqdn="${1:-}"
  [[ -n "$fqdn" ]] || soviez_migration_die MIGRATION_SOURCE_MAINTENANCE_FAILED "fqdn required"
  local root site conf
  root="$(soviez_migration_p21_nginx_root)"
  site="$root/source"
  mkdir -p "$site/www"
  conf="$site/maintenance.conf"
  cat > "$conf" <<EOF
# SOVIEZ_OWNED module=migration_source_transition version=phase21
server {
    listen 80;
    server_name ${fqdn};
    root ${site}/www;
    location /healthz {
        default_type application/json;
        return 200 '{"ok":true,"state":"maintenance"}';
    }
    location / {
        try_files /index.html =503;
    }
}
EOF
  soviez_migration_p21_nginx_validate_no_wildcard "$conf"
  printf '%s\n' "$conf"
}
