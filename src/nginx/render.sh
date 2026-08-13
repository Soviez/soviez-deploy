# shellcheck shell=bash

soviez_nginx_render_config() {
  local domain="$1"
  local upstream="$2"
  local out="${3:-$SOVIEZ_ROOT/nginx-${domain}.conf}"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mkdir -p "$SOVIEZ_ROOT/stubs"
    out="$SOVIEZ_ROOT/stubs/nginx-${domain}.conf"
  fi

  cat > "$out" <<EOF
server {
    listen 443 ssl;
    server_name ${domain};
    location / {
        proxy_pass http://${upstream};
    }
}
EOF
  soviez_log_debug "Wrote nginx config: $out"
}
