#!/usr/bin/env bash
# Soviez Registry Gateway — healthcheck (/live, /ready; /health alias)
set -euo pipefail

HOST="${SOVIEZ_RGW_HEALTH_HOST:-127.0.0.1}"
PORT="${PORT:-${SOVIEZ_RGW_HEALTH_PORT:-8087}}"
BASE="http://${HOST}:${PORT}"
STRICT="${SOVIEZ_RGW_HEALTH_STRICT:-1}"

log()  { printf '[soviez-rgw-health] %s\n' "$*"; }
fail() { printf '[soviez-rgw-health] FAIL: %s\n' "$*" >&2; exit 1; }

check_path() {
  local path="$1"
  local code body
  body="$(curl -fsS --max-time 5 "${BASE}${path}" 2>/dev/null)" || fail "${path} unreachable at ${BASE}${path}"
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "${BASE}${path}" || true)"
  [[ "${code}" == "200" ]] || fail "${path} HTTP ${code}"
  echo "${body}" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' || fail "${path} unexpected body: ${body}"
  log "OK ${path}"
}

command -v curl >/dev/null 2>&1 || fail "curl required"

check_path /live
check_path /ready
check_path /health

if [[ "${STRICT}" == "1" ]]; then
  log "All probes passed (${BASE})"
fi
exit 0
