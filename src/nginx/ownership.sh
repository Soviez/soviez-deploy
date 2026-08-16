# shellcheck shell=bash
# Phase 12 Nginx ownership model — never overwrite unmanaged configs.

soviez_nginx_owned_path() {
  local env_id="$1"
  local domain="$2"
  printf '%s/%s__%s.conf\n' "$SOVIEZ_SSL_NGINX_OWNED_DIR" "$env_id" "$domain"
}

soviez_nginx_owned_meta_path() {
  local conf="$1"
  printf '%s.meta.json\n' "$conf"
}

soviez_nginx_render_owned() {
  local env_id="$1"
  local domain="$2"
  local upstream="$3"
  local cert="$4"
  local key="$5"
  local op_id="${6:-}"
  local mode="${7:-https}" # http_temp|https
  local out meta checksum now
  soviez_ssl_paths_init
  out="$(soviez_nginx_owned_path "$env_id" "$domain")"
  meta="$(soviez_nginx_owned_meta_path "$out")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local staged="${out}.staged"

  # Collision: another env owns same domain (active or staged)
  local other
  for other in "$SOVIEZ_SSL_NGINX_OWNED_DIR"/*__"${domain}".conf "$SOVIEZ_SSL_NGINX_OWNED_DIR"/*__"${domain}".conf.staged; do
    [[ -e "$other" ]] || continue
    if [[ "$other" != "$out" && "$other" != "$staged" ]]; then
      soviez_ssl_die "$SOVIEZ_SSL_CODE_NGINX_CONFIG_CONFLICT" "Domain already owned by another managed config: $other"
    fi
  done

  if [[ "$mode" == "http_temp" ]]; then
    cat > "$staged" <<EOF
# SOVIEZ_OWNED env_id=${env_id} domain=${domain} module=ssl_lifecycle version=phase12
server {
    listen 80;
    server_name ${domain};
    location / {
        return 503 "Soviez provisioning incomplete — temporary HTTP only";
    }
}
EOF
  else
    local ws_upstream="${SOVIEZ_NGINX_WS_UPSTREAM:-}"
    if [[ -z "$ws_upstream" ]]; then
      # Owner-approved topology: HTTP :8069, WebSocket/gevent :8072 on same host.
      if [[ "$upstream" =~ ^(.+):8069$ ]]; then
        ws_upstream="${BASH_REMATCH[1]}:8072"
      else
        ws_upstream="$upstream"
      fi
    fi
    cat > "$staged" <<EOF
# SOVIEZ_OWNED env_id=${env_id} domain=${domain} module=ssl_lifecycle version=phase12-ws2
server {
    listen 80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name ${domain};
    ssl_certificate ${cert};
    ssl_certificate_key ${key};
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location /websocket {
        proxy_pass http://${ws_upstream};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }

    # Compatibility (Odoo 18): longpolling → evented backend when multi-worker
    location /longpolling {
        proxy_pass http://${ws_upstream};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }

    location / {
        proxy_pass http://${upstream};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_read_timeout 720s;
        proxy_buffering off;
    }
}
EOF
  fi

  # Note: requires http-level map \$http_upgrade \$connection_upgrade (ERP soviez_limits /
  # S2 hardened). Template assumes that map exists on supported hosts.

  checksum="$(openssl dgst -sha256 "$staged" | awk '{print $NF}')"
  ENV_ID="$env_id" DOMAIN="$domain" UP="$upstream" OP="$op_id" SUM="$checksum" NOW="$now" MODE="$mode" \
    python3 - <<'PY' > "$meta"
import json, os
print(json.dumps({
  "environment_id": os.environ["ENV_ID"],
  "domain": os.environ["DOMAIN"],
  "upstream": os.environ["UP"],
  "owner_module": "ssl_lifecycle",
  "operation_id": os.environ.get("OP") or None,
  "generated_at": os.environ["NOW"],
  "template_version": "phase12-ws1",
  "checksum": os.environ["SUM"],
  "state": "staged",
  "mode": os.environ["MODE"]
}, indent=2))
PY
  chmod 644 "$staged" "$meta"
  printf '%s\n' "$staged"
}

soviez_nginx_test_config() {
  local conf="$1"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Fixture: fail if marker present
    if grep -q 'SOVIEZ_FORCE_NGINX_T_FAIL' "$conf" 2>/dev/null; then
      return 1
    fi
    return 0
  fi
  if command -v nginx >/dev/null 2>&1; then
    nginx -t -c "$conf" >/dev/null 2>&1
  else
    # Without nginx binary, structural check only
    grep -q 'server_name' "$conf"
  fi
}

soviez_nginx_promote_owned() {
  local staged="$1"
  local final="${staged%.staged}"
  local prev="${final}.previous"
  if [[ -f "$final" ]]; then
    cp -f "$final" "$prev"
  fi
  if ! soviez_nginx_test_config "$staged"; then
    rm -f "$staged"
    soviez_ssl_die "$SOVIEZ_SSL_CODE_NGINX_VALIDATION_FAILED" "nginx -t failed for staged config"
  fi
  mv -f "$staged" "$final"
  local meta
  meta="$(soviez_nginx_owned_meta_path "$final")"
  if [[ -f "$meta" ]]; then
    python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["state"]="active"; json.dump(d, open(p,"w"), indent=2)' "$meta"
  fi
  printf '%s\n' "$final"
}

soviez_nginx_reload_safe() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_FORCE_NGINX_RELOAD_FAIL:-0}" == "1" ]]; then
      return 1
    fi
    return 0
  fi
  if command -v nginx >/dev/null 2>&1; then
    nginx -s reload
  else
    return 0
  fi
}

soviez_nginx_rollback_owned() {
  local final="$1"
  local prev="${final}.previous"
  [[ -f "$prev" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_ROLLBACK_FAILED" "No previous Nginx config to restore"
  cp -f "$prev" "$final"
  soviez_nginx_test_config "$final" || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_ROLLBACK_FAILED" "Rolled-back Nginx config failed nginx -t"
  soviez_nginx_reload_safe || soviez_ssl_die "$SOVIEZ_SSL_CODE_NGINX_RELOAD_FAILED" "Nginx reload failed after rollback"
}

# Unmanaged configs must never be deleted by soviez.
soviez_nginx_is_owned() {
  local path="$1"
  grep -q 'SOVIEZ_OWNED' "$path" 2>/dev/null
}
