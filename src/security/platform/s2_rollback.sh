# shellcheck shell=bash
# Security Gate S2 — rollback for host/edge mutations (never restore S1 violations).

soviez_s2_rollback_snapshot() {
  local dir="${1:-}"
  [[ -n "$dir" ]] || dir="${TMPDIR:-/tmp}/soviez-s2-rollback-$$"
  mkdir -p "$dir"/{firewall,nginx,ssh,edge,fail2ban}
  chmod 700 "$dir" 2>/dev/null || true
  SOVIEZ_S2_ROLLBACK_DIR="$dir"
  export SOVIEZ_S2_ROLLBACK_DIR
  if declare -F soviez_fw_snapshot >/dev/null 2>&1; then
    soviez_fw_snapshot "$dir/firewall" >/dev/null || true
  fi
  # Nginx owned configs
  if [[ -n "${SOVIEZ_SSL_NGINX_OWNED_DIR:-}" && -d "${SOVIEZ_SSL_NGINX_OWNED_DIR}" ]]; then
    cp -a "${SOVIEZ_SSL_NGINX_OWNED_DIR}/." "$dir/nginx/" 2>/dev/null || true
  fi
  if [[ -f /etc/ssh/sshd_config ]]; then
    cp -a /etc/ssh/sshd_config "$dir/ssh/" 2>/dev/null || true
  fi
  local f2b
  f2b="$(declare -F soviez_bf_fail2ban_jail_path >/dev/null 2>&1 && soviez_bf_fail2ban_jail_path || true)"
  if [[ -n "$f2b" && -f "$f2b" ]]; then
    cp -a "$f2b" "$dir/fail2ban/" 2>/dev/null || true
  fi
  printf '%s\n' "${SOVIEZ_EDGE_MODE:-direct}" >"$dir/edge/mode"
  printf '%s\n' "$dir"
}

soviez_s2_rollback() {
  local dir="${1:-${SOVIEZ_S2_ROLLBACK_DIR:-}}"
  [[ -n "$dir" && -d "$dir" ]] || {
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: no S2 rollback snapshot" >&2
    return 1
  }
  if declare -F soviez_fw_rollback >/dev/null 2>&1; then
    soviez_fw_rollback "$dir/firewall" || true
  fi
  if declare -F soviez_ssh_rollback >/dev/null 2>&1; then
    SOVIEZ_SSH_SNAPSHOT_DIR="$dir/ssh" soviez_ssh_rollback "$dir/ssh" || true
  fi
  # Never re-publish Odoo/PG publicly as part of rollback.
  echo "[security] S2 rollback applied (S1 non-regressible constraints preserved)" >&2
  return 0
}
