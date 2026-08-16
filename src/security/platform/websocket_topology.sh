# shellcheck shell=bash
# Certified WebSocket topology (owner-approved multi-worker correction).
# SUPPORTED: workers calculated by sizing engine; when workers>0:
#   HTTP 127.0.0.1:8069 + gevent/evented 127.0.0.1:8072
#   Nginx / → 8069, /websocket → 8072
# Minimal hosts may fall back to workers=0 (single-process compat on 8069).

soviez_ws_certified_workers_max() {
  # No hard product cap; sizing engine decides. Report high watermark for docs.
  printf '64\n'
}

# soviez_ws_assert_odoo_conf <conf-path>
# Requires proxy_mode=True. When workers>0, gevent_port must be 8072.
soviez_ws_assert_odoo_conf() {
  local conf="${1:-}"
  [[ -f "$conf" ]] || {
    echo "SEC_HIGH_WS_CONF_MISSING conf=$conf" >&2
    return 1
  }
  if ! grep -Eiq '^[[:space:]]*proxy_mode[[:space:]]*=[[:space:]]*True' "$conf"; then
    echo "SEC_CRIT_WS_PROXY_MODE conf=$conf" >&2
    return 1
  fi
  local workers gevent
  workers="$(grep -Ei '^[[:space:]]*workers[[:space:]]*=' "$conf" | tail -1 | sed -E 's/.*=[[:space:]]*//;s/[[:space:]]*$//' || echo 0)"
  workers="${workers:-0}"
  if [[ "$workers" =~ ^[0-9]+$ ]] && (( workers > 0 )); then
    gevent="$(grep -Ei '^[[:space:]]*gevent_port[[:space:]]*=' "$conf" | tail -1 | sed -E 's/.*=[[:space:]]*//;s/[[:space:]]*$//' || echo "")"
    if [[ "$gevent" != "8072" ]]; then
      echo "SEC_CRIT_WS_GEVENT_PORT workers=$workers gevent_port=${gevent:-unset} (required 8072)" >&2
      return 1
    fi
  fi
  return 0
}

# soviez_ws_assert_nginx_snippet <conf> [expect_gevent=0|1]
# Requires /websocket + Upgrade headers. When expect_gevent=1, /websocket must target :8072.
soviez_ws_assert_nginx_snippet() {
  local conf="${1:-}"
  local expect_gevent="${2:-0}"
  [[ -f "$conf" ]] || return 1
  grep -q 'location /websocket' "$conf" || {
    echo "SEC_HIGH_WS_NGINX_MISSING_WEBSOCKET" >&2
    return 1
  }
  grep -q 'Upgrade' "$conf" || {
    echo "SEC_HIGH_WS_NGINX_MISSING_UPGRADE" >&2
    return 1
  }
  if [[ "$expect_gevent" == "1" ]]; then
    if ! grep -E 'location /websocket' -A20 "$conf" | grep -Eq '127\.0\.0\.1:8072|:8072'; then
      echo "SEC_CRIT_WS_NGINX_WEBSOCKET_NOT_8072" >&2
      return 1
    fi
  fi
  return 0
}

# Classify longpolling support for docs/tests.
soviez_ws_longpolling_status() {
  printf 'COMPATIBILITY_ROUTED\n'
}

# Expected backends for a given worker count.
soviez_ws_http_backend() {
  printf '127.0.0.1:8069\n'
}

soviez_ws_websocket_backend() {
  local workers="${1:-0}"
  if [[ "$workers" =~ ^[0-9]+$ ]] && (( workers > 0 )); then
    printf '127.0.0.1:8072\n'
  else
    printf '127.0.0.1:8069\n'
  fi
}
