# shellcheck shell=bash
# Security Gate S2 — firewalld backend (idempotent; never --complete-reload).

soviez_fw_firewalld_apply() {
  local ssh_port="${1:-22}"
  if ! command -v firewall-cmd >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: firewall-cmd missing" >&2
    return 1
  fi
  firewall-cmd --permanent --add-service=http >/dev/null 2>&1 || \
    firewall-cmd --permanent --add-port=80/tcp >/dev/null 2>&1 || true
  firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || \
    firewall-cmd --permanent --add-port=443/tcp >/dev/null 2>&1 || true
  if [[ "$ssh_port" == "22" ]]; then
    firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
  else
    firewall-cmd --permanent --add-port="${ssh_port}/tcp" >/dev/null 2>&1 || true
  fi
  # Reload (not complete-reload) to apply permanent rules.
  firewall-cmd --reload >/dev/null 2>&1 || true
  return 0
}
