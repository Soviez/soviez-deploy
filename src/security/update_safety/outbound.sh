# shellcheck shell=bash
# Security Gate S5 — bounded outbound reachability (EXPECTED_OFFLINE aware).

soviez_s5_check_outbound() {
  if [[ "${SOVIEZ_S5_OFFLINE:-0}" == "1" || "${SOVIEZ_S5_QUARANTINE:-0}" == "1" ]]; then
    echo EXPECTED_OFFLINE
    return 0
  fi

  if [[ "${SOVIEZ_S5_INJECT_OUTBOUND_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  local url="${SOVIEZ_S5_HEALTH_URL:-http://1.1.1.1}"
  local cid="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local timeout="${SOVIEZ_S5_OUTBOUND_TIMEOUT:-3}"

  # Prefer probe from container namespace when available.
  if [[ -n "$cid" ]] && command -v docker >/dev/null 2>&1; then
    if docker exec "$cid" sh -c \
      "wget -q -O- --timeout=${timeout} '${url}' >/dev/null 2>&1 || curl -fsS --max-time ${timeout} '${url}' >/dev/null 2>&1" \
      2>/dev/null; then
      echo PASS
      return 0
    fi
    echo FAIL
    return 1
  fi

  if command -v wget >/dev/null 2>&1; then
    if wget -q -O- --timeout="$timeout" "$url" >/dev/null 2>&1; then
      echo PASS
      return 0
    fi
  elif command -v curl >/dev/null 2>&1; then
    if curl -fsS --max-time "$timeout" "$url" >/dev/null 2>&1; then
      echo PASS
      return 0
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Unit tests without network tools: treat as SKIP rather than false FAIL.
    echo SKIP
    return 0
  fi

  echo FAIL
  return 1
}
