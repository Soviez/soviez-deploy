# shellcheck shell=bash
# Security Gate S5 — DNS validation from container network namespace.

soviez_s5_check_dns() {
  local cid="${1:-${SOVIEZ_SEC_ODOO_CONTAINER:-}}"
  local internal="${SOVIEZ_S5_DNS_TARGET:-db}"
  local external="${SOVIEZ_S5_DNS_EXTERNAL:-one.one.one.one}"

  if [[ "${SOVIEZ_S5_INJECT_DNS_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  if [[ -z "$cid" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_S5_REQUIRE_CONTAINERS:-0}" != "1" ]]; then
      # Host-level fallback for fixture unit tests.
      if getent hosts localhost >/dev/null 2>&1 || nslookup localhost >/dev/null 2>&1; then
        echo PASS
        return 0
      fi
    fi
    echo FAIL
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo FAIL
    return 1
  fi

  # Internal / Docker DNS (service name).
  if ! docker exec "$cid" sh -c \
    "getent hosts ${internal} >/dev/null 2>&1 || nslookup ${internal} >/dev/null 2>&1 || host ${internal} >/dev/null 2>&1" \
    2>/dev/null; then
    echo FAIL
    return 1
  fi

  # External DNS — skip when intentionally offline/quarantined.
  if [[ "${SOVIEZ_S5_OFFLINE:-0}" == "1" || "${SOVIEZ_S5_QUARANTINE:-0}" == "1" ]]; then
    echo PASS
    return 0
  fi

  if docker exec "$cid" sh -c \
    "getent hosts ${external} >/dev/null 2>&1 || nslookup ${external} >/dev/null 2>&1 || host ${external} >/dev/null 2>&1" \
    2>/dev/null; then
    echo PASS
    return 0
  fi

  echo FAIL
  return 1
}
