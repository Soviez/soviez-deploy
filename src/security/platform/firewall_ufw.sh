# shellcheck shell=bash
# Security Gate S2 — UFW backend (idempotent; never ufw reset).

soviez_fw_ufw_ensure_rule() {
  local rule="$1"
  # Idempotent: skip if already present in ufw status.
  if ufw status 2>/dev/null | grep -Fqi -- "$rule"; then
    return 0
  fi
  # shellcheck disable=SC2086
  ufw allow $rule >/dev/null 2>&1 || ufw allow "$rule" >/dev/null 2>&1 || true
}

soviez_fw_ufw_apply() {
  local ssh_port="${1:-22}"
  if ! command -v ufw >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: ufw missing" >&2
    return 1
  fi
  # Open required ports BEFORE enable — preserve SSH.
  soviez_fw_ufw_ensure_rule "${ssh_port}/tcp"
  if [[ "$ssh_port" == "22" ]]; then
    soviez_fw_ufw_ensure_rule "OpenSSH"
  fi
  soviez_fw_ufw_ensure_rule "80/tcp"
  soviez_fw_ufw_ensure_rule "443/tcp"
  # Default deny inbound when enabling (ufw default); do not flush.
  ufw default deny incoming >/dev/null 2>&1 || true
  ufw default allow outgoing >/dev/null 2>&1 || true
  # Enable without reset — must succeed on Production Linux hosts.
  # Note: do not grep bare "active" (matches "inactive").
  if ! ufw status 2>/dev/null | head -1 | grep -Eqi 'Status:[[:space:]]*active'; then
    if ! ufw --force enable >/dev/null 2>&1; then
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: ufw enable failed" >&2
      return 1
    fi
  fi
  return 0
}

soviez_fw_ufw_rollback() {
  local dir="$1"
  # Soft rollback: re-ensure SSH/80/443 from snapshot intent; never open app/db ports.
  local ssh_port="${SOVIEZ_SSH_PORT:-22}"
  soviez_fw_ufw_ensure_rule "${ssh_port}/tcp"
  soviez_fw_ufw_ensure_rule "80/tcp"
  soviez_fw_ufw_ensure_rule "443/tcp"
  [[ -f "$dir/ufw.status" ]] || true
}
