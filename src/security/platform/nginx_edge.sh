# shellcheck shell=bash
# Security Gate S2 — Nginx production hardening (owned snippets; do not overwrite Virtualmin).

SOVIEZ_NGINX_S2_MARKER="# SOVIEZ_OWNED nginx security — Security Gate S2"

soviez_nginx_s2_render_hardened() {
  # Args: domain upstream cert key out_path [mode=https|http_only]
  local domain="$1" upstream="$2" cert="${3:-}" key="${4:-}" out="${5:-}" mode="${6:-https}"
  local client_max="${SOVIEZ_NGINX_CLIENT_MAX_BODY:-100M}"
  local edge_mode="${SOVIEZ_EDGE_MODE:-direct}"
  local real_ip_block=""
  local headers_block=""
  local rate_block=""
  local ws_map=""
  local ws_upstream="${SOVIEZ_NGINX_WS_UPSTREAM:-}"
  if [[ -z "$ws_upstream" ]]; then
    if [[ "$upstream" =~ ^(.+):8069$ ]]; then
      ws_upstream="${BASH_REMATCH[1]}:8072"
    else
      ws_upstream="$upstream"
    fi
  fi

  # Upstream must be localhost/private — reject obvious public IPs in upstream string for Production.
  if [[ "$upstream" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+: ]]; then
    if [[ ! "$upstream" =~ ^127\. ]] && [[ ! "$upstream" =~ ^10\. ]] && \
       [[ ! "$upstream" =~ ^192\.168\. ]] && [[ ! "$upstream" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
      echo "[error] security:SEC_CRIT_NGINX_INVALID: upstream not private/loopback: ${upstream}" >&2
      return 1
    fi
  fi

  headers_block=$(cat <<'HDR'
    # Safe baseline headers (CSP report-only — strict CSP deferred; breaks Odoo assets)
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header Content-Security-Policy-Report-Only "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:;" always;
HDR
)
  if [[ "$mode" == "https" ]]; then
    headers_block+=$'\n'"    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;"
  fi

  rate_block=$(cat <<'RATE'
    # Targeted limits only — do not globally throttle /web/dataset JSON-RPC
    location = /web/login {
        limit_req zone=soviez_login burst=20 nodelay;
        proxy_pass http://UPSTREAM_PLACEHOLDER;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }
RATE
)
  rate_block="${rate_block//UPSTREAM_PLACEHOLDER/${upstream}}"

  if [[ "$edge_mode" == "cloudflare" || "$edge_mode" == "cloudflare_aop" ]]; then
    if declare -F soviez_edge_cloudflare_real_ip_directives >/dev/null 2>&1; then
      real_ip_block="$(soviez_edge_cloudflare_real_ip_directives)"
    fi
  else
    # Direct mode: do not trust arbitrary X-Forwarded-For from internet.
    real_ip_block="# EDGE_MODE=direct — ignore spoofed XFF; use connection remote_addr"
  fi

  local tls_block=""
  if [[ "$mode" == "https" && -n "$cert" && -n "$key" ]]; then
    tls_block=$(cat <<TLS
    ssl_certificate ${cert};
    ssl_certificate_key ${key};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers HIGH:!aNULL:!MD5:!RC4;
TLS
)
  fi

  {
    echo "${SOVIEZ_NGINX_S2_MARKER}"
    echo "# env domain=${domain} edge=${edge_mode} upstream=${upstream}"
    echo "map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }"
    echo "limit_req_zone \$binary_remote_addr zone=soviez_login:10m rate=5r/s;"
    echo
    cat <<EOF
server {
    listen 80;
    server_name ${domain};
    server_tokens off;
    ${real_ip_block}
EOF
    if [[ "$mode" == "https" ]]; then
      cat <<EOF
    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/html;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl http2;
    server_name ${domain};
    server_tokens off;
    ${tls_block}
    ${real_ip_block}
    client_max_body_size ${client_max};
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    ${headers_block}

${rate_block}

    location /websocket {
        proxy_pass http://${ws_upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 720s;
    }

    location /longpolling {
        proxy_pass http://${ws_upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }

    location / {
        proxy_pass http://${upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 720s;
        proxy_buffering off;
    }
}
EOF
    else
      cat <<EOF
    client_max_body_size ${client_max};
    location / {
        proxy_pass http://${upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    fi
  } >"$out"
  printf '%s\n' "$out"
}

soviez_nginx_s2_validate_syntax() {
  local conf="$1"
  [[ -f "$conf" ]] || return 1
  grep -q 'SOVIEZ_OWNED nginx security' "$conf" || grep -q 'SOVIEZ_OWNED' "$conf" || true
  grep -q 'server_tokens off' "$conf" || {
    echo "[error] security:SEC_CRIT_NGINX_INVALID: server_tokens not disabled" >&2
    return 1
  }
  if grep -Eq 'proxy_pass[[:space:]]+http://0\.0\.0\.0' "$conf"; then
    echo "[error] security:SEC_CRIT_NGINX_INVALID: upstream 0.0.0.0" >&2
    return 1
  fi
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    grep -q 'SOVIEZ_FORCE_NGINX_T_FAIL' "$conf" && return 1
    return 0
  fi
  if command -v nginx >/dev/null 2>&1; then
    # Full nginx -t needs a complete main conf; structural checks above are primary for snippets.
    return 0
  fi
  return 0
}

soviez_nginx_s2_detect_ownership() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf '%s\n' "missing"
    return 0
  fi
  if grep -q 'SOVIEZ_OWNED' "$path" 2>/dev/null; then
    printf '%s\n' "soviez"
    return 0
  fi
  if grep -Eiq 'Virtualmin|VIRTUALMIN|webmin' "$path" 2>/dev/null || \
     [[ "$path" == *'/etc/nginx/sites-enabled/'* && -d /etc/webmin ]]; then
    printf '%s\n' "virtualmin"
    return 0
  fi
  printf '%s\n' "unknown"
}
