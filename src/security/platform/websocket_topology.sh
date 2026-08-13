# shellcheck shell=bash
# Certified WebSocket topology (post-cert discrepancy closure).
# SUPPORTED_AND_CERTIFIED: workers=0, proxy_mode=True, /websocket → HTTP :8069 (loopback).
# workers>0 / dedicated gevent_port publish: NOT_SUPPORTED.

soviez_ws_certified_workers_max() {
  printf '0\n'
}

# soviez_ws_assert_odoo_conf <conf-path>
# Fails closed if proxy_mode missing/false or workers>0.
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
  local workers
  workers="$(grep -Ei '^[[:space:]]*workers[[:space:]]*=' "$conf" | tail -1 | sed -E 's/.*=[[:space:]]*//;s/[[:space:]]*$//' || echo 0)"
  workers="${workers:-0}"
  if [[ "$workers" =~ ^[0-9]+$ ]] && (( workers > 0 )); then
    echo "SEC_HIGH_WS_WORKERS_UNSUPPORTED workers=$workers (certified topology requires 0)" >&2
    return 1
  fi
  if grep -Eiq '^[[:space:]]*gevent_port[[:space:]]*=' "$conf"; then
    echo "SEC_HIGH_WS_GEVENT_UNSUPPORTED gevent_port set (NOT_SUPPORTED)" >&2
    return 1
  fi
  return 0
}

# soviez_ws_assert_nginx_snippet <conf>
# Requires /websocket + Upgrade headers; /longpolling optional (compat).
soviez_ws_assert_nginx_snippet() {
  local conf="${1:-}"
  [[ -f "$conf" ]] || return 1
  grep -q 'location /websocket' "$conf" || {
    echo "SEC_HIGH_WS_NGINX_MISSING_WEBSOCKET" >&2
    return 1
  }
  grep -q 'Upgrade' "$conf" || {
    echo "SEC_HIGH_WS_NGINX_MISSING_UPGRADE" >&2
    return 1
  }
  return 0
}

# Classify longpolling support for docs/tests.
soviez_ws_longpolling_status() {
  printf 'COMPATIBILITY_ROUTED\n'
}
