# shellcheck shell=bash
# Security Gate S5 — Docker restart safety validation.

soviez_s5_docker_restart_validate() {
  local web="${1:-${SOVIEZ_SEC_ODOO_CONTAINER:-}}"
  local pg="${2:-${SOVIEZ_SEC_PG_CONTAINER:-}}"
  local probe="${3:-}"

  if [[ "${SOVIEZ_S5_SKIP_DOCKER_RESTART:-0}" == "1" ]]; then
    echo SKIP
    return 0
  fi

  if [[ -z "$web" || -z "$pg" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      echo SKIP
      return 0
    fi
    echo FAIL
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo FAIL
    return 1
  fi

  # Restart web + pg (and optional probe).
  docker restart "$pg" >/dev/null 2>&1 || { echo FAIL; return 1; }
  docker restart "$web" >/dev/null 2>&1 || { echo FAIL; return 1; }
  if [[ -n "$probe" ]]; then
    docker restart "$probe" >/dev/null 2>&1 || true
  fi

  # Wait briefly for readiness.
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if docker inspect -f '{{.State.Running}}' "$web" 2>/dev/null | grep -qi true \
      && docker inspect -f '{{.State.Running}}' "$pg" 2>/dev/null | grep -qi true; then
      break
    fi
    sleep 1
  done

  # Containers-up alone is NOT success — recheck DNS/PG/ports.
  local dns_r pg_r ports_r
  dns_r="$(soviez_s5_check_dns "$web" 2>/dev/null || echo FAIL)"
  pg_r="$(soviez_s5_check_odoo_pg "$web" "$pg" 2>/dev/null || echo FAIL)"
  ports_r="$(soviez_s5_check_ports_protected "$web" "$pg" 2>/dev/null || echo FAIL)"

  if [[ "$dns_r" == "PASS" || "$dns_r" == "SKIP" ]] \
    && [[ "$pg_r" == "PASS" || "$pg_r" == "SKIP" ]] \
    && [[ "$ports_r" == "PASS" ]]; then
    echo PASS
    return 0
  fi

  echo "[error] security:SEC_HIGH_DOCKER_FORWARDING_BROKEN: post-restart dns=${dns_r} pg=${pg_r} ports=${ports_r}" >&2
  echo FAIL
  return 1
}
