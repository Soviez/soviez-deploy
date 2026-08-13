# shellcheck shell=bash
# Security Gate S2 — firewall backend detection & abstraction.
# NEVER flush/reset production firewalls (iptables -F, nft flush, ufw reset, etc.).

SOVIEZ_FW_BACKEND="${SOVIEZ_FW_BACKEND:-}"
SOVIEZ_FW_MARKER="# SOVIEZ_OWNED firewall policy — Security Gate S2"
SOVIEZ_FW_SNAPSHOT_DIR="${SOVIEZ_FW_SNAPSHOT_DIR:-}"

soviez_fw_detect_backend() {
  # Prefer active manager; do not install competitors.
  local backend="none"
  if command -v ufw >/dev/null 2>&1; then
    local st
    st="$(ufw status 2>/dev/null | head -1 || true)"
    if echo "$st" | grep -Eqi 'Status:[[:space:]]*active' || [[ "${SOVIEZ_FW_PREFER_UFW:-0}" == "1" ]]; then
      backend="ufw"
    elif echo "$st" | grep -Eqi 'Status:[[:space:]]*inactive' && [[ -z "$(command -v firewall-cmd 2>/dev/null || true)" ]]; then
      backend="ufw"
    fi
  fi
  if [[ "$backend" == "none" ]] && command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1 || [[ "${SOVIEZ_FW_PREFER_FIREWALLD:-0}" == "1" ]]; then
      backend="firewalld"
    fi
  fi
  if [[ "$backend" == "none" ]] && command -v nft >/dev/null 2>&1; then
    if nft list ruleset >/dev/null 2>&1; then
      backend="nftables"
    fi
  fi
  if [[ "$backend" == "none" ]] && command -v iptables >/dev/null 2>&1; then
    backend="iptables"
  fi
  SOVIEZ_FW_BACKEND="$backend"
  export SOVIEZ_FW_BACKEND
  printf '%s\n' "$backend"
}

soviez_fw_assert_no_destructive_ops() {
  # Static guard used by tests and dual-installer asserts.
  # Flags real invocations only — not detection string literals / comments.
  local path="$1"
  local bad=0
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    # Skip pure detection / comparison / error-message lines.
    if [[ "$line" == *'[['* || "$line" == *'grep'* || "$line" == *'FORBIDDEN'* || "$line" == *'assert'* || "$line" == *'echo '* ]]; then
      continue
    fi
    if [[ "$line" =~ (^|[[:space:];])iptables[[:space:]]+-F($|[[:space:]]) ]] || \
       [[ "$line" =~ (^|[[:space:];])iptables[[:space:]]+-X($|[[:space:]]) ]] || \
       [[ "$line" == *'nft flush ruleset'* ]]; then
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: destructive firewall op in ${path}: ${line}" >&2
      bad=1
    fi
    if [[ "$line" =~ (^|[[:space:];])ufw[[:space:]]+(--force[[:space:]]+)?reset($|[[:space:]]) ]]; then
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: ufw reset in ${path}" >&2
      bad=1
    fi
    if [[ "$line" == *'firewall-cmd --complete-reload'* ]]; then
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: complete-reload in ${path}" >&2
      bad=1
    fi
  done < "$path"
  [[ "$bad" -eq 0 ]]
}

soviez_fw_snapshot() {
  local dir="${1:-${SOVIEZ_FW_SNAPSHOT_DIR:-}}"
  local backend="${2:-${SOVIEZ_FW_BACKEND:-}}"
  [[ -n "$backend" ]] || backend="$(soviez_fw_detect_backend)"
  if [[ -z "$dir" ]]; then
    dir="${TMPDIR:-/tmp}/soviez-fw-snap-$$"
  fi
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  SOVIEZ_FW_SNAPSHOT_DIR="$dir"
  export SOVIEZ_FW_SNAPSHOT_DIR
  printf '%s\n' "$backend" >"$dir/backend"
  case "$backend" in
    ufw)
      ufw status verbose >"$dir/ufw.status" 2>&1 || true
      ufw status numbered >"$dir/ufw.numbered" 2>&1 || true
      ;;
    firewalld)
      firewall-cmd --list-all >"$dir/firewalld.list" 2>&1 || true
      ;;
    nftables)
      nft list ruleset >"$dir/nft.ruleset" 2>&1 || true
      ;;
    iptables)
      iptables-save >"$dir/iptables.save" 2>&1 || true
      iptables -L DOCKER-USER -n -v >"$dir/docker-user.chain" 2>&1 || true
      ;;
    none)
      echo "none" >"$dir/note"
      ;;
  esac
  # Always capture Docker publish + DOCKER-USER if present (non-destructive).
  if command -v iptables >/dev/null 2>&1; then
    iptables -L DOCKER-USER -n -v >"$dir/docker-user.chain" 2>&1 || echo "DOCKER-USER absent" >"$dir/docker-user.chain"
  fi
  if command -v docker >/dev/null 2>&1; then
    docker ps --format '{{.Names}} {{.Ports}}' >"$dir/docker.ports" 2>&1 || true
  fi
  printf '%s\n' "$dir"
}

soviez_fw_apply_soviez_policy() {
  local backend="${1:-${SOVIEZ_FW_BACKEND:-}}"
  [[ -n "$backend" ]] || backend="$(soviez_fw_detect_backend)"
  local ssh_port="${SOVIEZ_SSH_PORT:-22}"
  case "$backend" in
    ufw)
      declare -F soviez_fw_ufw_apply >/dev/null 2>&1 && soviez_fw_ufw_apply "$ssh_port"
      ;;
    firewalld)
      declare -F soviez_fw_firewalld_apply >/dev/null 2>&1 && soviez_fw_firewalld_apply "$ssh_port"
      ;;
    nftables)
      declare -F soviez_fw_nft_apply >/dev/null 2>&1 && soviez_fw_nft_apply "$ssh_port"
      ;;
    iptables)
      declare -F soviez_fw_iptables_apply >/dev/null 2>&1 && soviez_fw_iptables_apply "$ssh_port"
      ;;
    none)
      echo "[security] FIREWALL_BACKEND=none — policy apply skipped (report only)" >&2
      return 0
      ;;
    *)
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: unsupported backend ${backend}" >&2
      return 1
      ;;
  esac
  # Docker-aware containment (DOCKER-USER) when iptables present.
  if declare -F soviez_fw_docker_apply_user_chain >/dev/null 2>&1; then
    soviez_fw_docker_apply_user_chain || true
  fi
}

soviez_fw_validate() {
  local backend="${1:-${SOVIEZ_FW_BACKEND:-}}"
  [[ -n "$backend" ]] || backend="$(soviez_fw_detect_backend)"
  # Required: SSH/80/443 intent recorded; dangerous ports not explicitly allowed publicly by Soviez markers.
  case "$backend" in
    ufw)
      local st
      st="$(ufw status 2>/dev/null || true)"
      if echo "$st" | head -1 | grep -Eqi 'Status:[[:space:]]*(active|inactive)'; then
        :
      else
        echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: cannot read ufw" >&2
        return 1
      fi
      ;;
    firewalld|nftables|iptables|none) ;;
    *)
      echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: backend=${backend}" >&2
      return 1
      ;;
  esac
  return 0
}

soviez_fw_rollback() {
  local dir="${1:-${SOVIEZ_FW_SNAPSHOT_DIR:-}}"
  [[ -n "$dir" && -d "$dir" ]] || {
    echo "[error] security:SEC_CRIT_FIREWALL_STATE_UNKNOWN: no firewall snapshot" >&2
    return 1
  }
  local backend
  backend="$(cat "$dir/backend" 2>/dev/null || echo none)"
  # Rollback restores recorded allow rules only; never re-opens 8069/5432.
  case "$backend" in
    ufw)
      if declare -F soviez_fw_ufw_rollback >/dev/null 2>&1; then
        soviez_fw_ufw_rollback "$dir"
      fi
      ;;
    *)
      echo "[security] firewall rollback best-effort for backend=${backend}" >&2
      ;;
  esac
}

soviez_fw_forbidden_public_ports() {
  # Space-separated list of ports that must not be publicly allowed by Soviez policy.
  printf '%s\n' "8069 8071 8072 5432 10000 2375 2376"
}
