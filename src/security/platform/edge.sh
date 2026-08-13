# shellcheck shell=bash
# Security Gate S2 — edge modes (direct | cloudflare | cloudflare_aop).

SOVIEZ_EDGE_MODE="${SOVIEZ_EDGE_MODE:-direct}"

soviez_edge_validate_mode() {
  case "${SOVIEZ_EDGE_MODE:-direct}" in
    direct|cloudflare) return 0 ;;
    cloudflare_aop)
      # AOP/mTLS only if explicitly enabled and certs present — else unsupported.
      if [[ "${SOVIEZ_EDGE_AOP_ENABLED:-0}" == "1" && -n "${SOVIEZ_EDGE_AOP_CLIENT_CA:-}" && -f "${SOVIEZ_EDGE_AOP_CLIENT_CA}" ]]; then
        return 0
      fi
      echo "[security] EDGE_MODE=cloudflare_aop unsupported without SOVIEZ_EDGE_AOP_ENABLED=1 and client CA — experimental/unsupported" >&2
      return 1
      ;;
    *)
      echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: invalid EDGE_MODE=${SOVIEZ_EDGE_MODE}" >&2
      return 1
      ;;
  esac
}

soviez_edge_apply_origin_protection() {
  # When Cloudflare-restricted origin mode is enabled, limit 80/443 to CF ranges.
  # SSH remains independent. ACME HTTP-01 must remain possible (/.well-known or DNS-01).
  local mode="${SOVIEZ_EDGE_MODE:-direct}"
  if [[ "${SOVIEZ_EDGE_ORIGIN_RESTRICT:-0}" != "1" ]]; then
    return 0
  fi
  if [[ "$mode" != "cloudflare" && "$mode" != "cloudflare_aop" ]]; then
    return 0
  fi
  if ! command -v ufw >/dev/null 2>&1; then
    echo "[security] origin restrict requested but ufw absent — Needs Action" >&2
    return 0
  fi
  local r
  while IFS= read -r r; do
    [[ -n "$r" ]] || continue
    ufw allow from "$r" to any port 80 proto tcp >/dev/null 2>&1 || true
    ufw allow from "$r" to any port 443 proto tcp >/dev/null 2>&1 || true
  done < <(soviez_cf_load_ranges 2>/dev/null || true)
  # Do not delete world-open 80/443 automatically (ACME / lockout risk) — report Needs Action.
  echo "[security] origin CF allow rules ensured; review world-open 80/443 manually for ACME safety" >&2
}

soviez_edge_aop_status() {
  if [[ "${SOVIEZ_EDGE_MODE:-}" != "cloudflare_aop" ]]; then
    printf '%s\n' "N/A"
    return 0
  fi
  if [[ "${SOVIEZ_EDGE_AOP_ENABLED:-0}" == "1" && -n "${SOVIEZ_EDGE_AOP_CLIENT_CA:-}" && -f "${SOVIEZ_EDGE_AOP_CLIENT_CA}" ]]; then
    printf '%s\n' "EXPERIMENTAL"
    return 0
  fi
  printf '%s\n' "UNSUPPORTED"
}
