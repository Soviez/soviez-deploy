# shellcheck shell=bash
# Security Gate S1 — dual-installer ownership bridge.
#
# Canonical source of truth for S1 platform semantics: soviez-sh
#   src/security/platform/*.sh (assembled into dist/soviez.sh).
# ERP monolith (`Soviez ERP/soviez.sh`) and legacy deploy copy
# (`soviez-deploy/soviez.sh`) MUST match S1 semantics (least-privilege
# PG roles, loopback Odoo publish, no privileged/docker.sock/host-net).
# After patching ERP, sync byte-identical copy to legacy via cp.

soviez_sec_legacy_assert_installer_safe() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: legacy assert missing file: ${path:-}" >&2
    return 1
  fi

  local bad=0
  local line

  # Public Odoo publish without loopback (literal unsafe pattern).
  if grep -Fq -- '-p "${SOVIEZ_HOST_PORT}:8069"' "$path"; then
    echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: unsafe -p \"\${SOVIEZ_HOST_PORT}:8069\" without 127.0.0.1 in ${path}" >&2
    bad=1
  fi
  if grep -Fq -- '-p "${stage_port}:8069"' "$path"; then
    echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: unsafe -p \"\${stage_port}:8069\" without 127.0.0.1 in ${path}" >&2
    bad=1
  fi

  # Bootstrap POSTGRES_USER must not be app role name "soviez" after S1.
  if grep -E -q -- 'POSTGRES_USER=soviez([[:space:]]|$)' "$path"; then
    echo "[error] security:SEC_CRIT_WEAK_ADMIN_CREDENTIAL: POSTGRES_USER=soviez used as bootstrap (expect soviez_admin) in ${path}" >&2
    bad=1
  fi

  # --privileged as a docker run/create flag (ignore comments / string equality checks).
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ (^|[[:space:]])--privileged([[:space:]]|$) ]]; then
      echo "[error] security:SEC_CRIT_PRIVILEGED_CONTAINER: --privileged docker flag in ${path}" >&2
      bad=1
      break
    fi
  done < "$path"

  # docker.sock bind-mount / volume publish (ignore detection code that only greps for it).
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" == *'/var/run/docker.sock'* ]] || [[ "$line" == *'-v '* && "$line" == *'docker.sock'* ]]; then
      # Skip pure grep/inspect detection lines that do not mount.
      if [[ "$line" == *'grep'* || "$line" == *'inspect'* ]]; then
        continue
      fi
      echo "[error] security:SEC_CRIT_DOCKER_SOCKET: docker.sock mount in ${path}" >&2
      bad=1
      break
    fi
  done < "$path"

  # --network host for web/db docker run (ignore NetworkMode equality checks).
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ --network[[:space:]]+host|--network=host ]]; then
      echo "[error] security:SEC_CRIT_HOST_NETWORK: --network host for web/db in ${path}" >&2
      bad=1
      break
    fi
  done < "$path"

  [[ "$bad" -eq 0 ]]
}

soviez_sec_legacy_assert_s2_firewall_safe() {
  # Dual-installer: Production paths must not broad-flush firewalls.
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: missing installer ${path:-}" >&2
    return 1
  fi
  if declare -F soviez_fw_assert_no_destructive_ops >/dev/null 2>&1; then
    soviez_fw_assert_no_destructive_ops "$path"
  else
    ! grep -E '^[[:space:]]*(iptables -F|iptables -X|nft flush ruleset|ufw --force reset|ufw reset|firewall-cmd --complete-reload)' "$path" \
      >/dev/null 2>&1
  fi
}

soviez_sec_legacy_assert_apt_lock_safe() {
  # S5 corr1: dual Production wizard must not kill apt/dpkg/unattended-upgrades.
  local path="$1"
  if declare -F soviez_pkg_assert_installer_no_kill >/dev/null 2>&1; then
    soviez_pkg_assert_installer_no_kill "$path" >/dev/null
    return $?
  fi
  if grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+apt' "$path" >/dev/null 2>&1; then
    echo "[error] security:PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED: ${path}" >&2
    return 1
  fi
  if grep -nE '^[[:space:]]*rm -f' "$path" | grep -q . && grep -A20 'heal_apt_locks\|Clear stuck apt' "$path" | grep -q '/var/lib/dpkg/lock'; then
    # Heuristic: heal function that rms locks
    if awk '/^heal_apt_locks\(/,/^}/ { if ($0 ~ /^[[:space:]]*rm -f/ && p~/lock/) bad=1; p=$0 } END{exit bad?0:1}' "$path" 2>/dev/null; then
      :
    fi
  fi
  # Explicit: no killall -9 of package managers in executable lines.
  ! grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+(apt|apt-get|dpkg|unattended)' "$path" >/dev/null 2>&1
}

soviez_sec_source_platform_modules() {
  local root="${SOVIEZ_SH_ROOT:-}"
  local mod
  local -a mods=(
    report.sh
    secrets_baseline.sh
    credential_policy.sh
    postgres_roles.sh
    postgres_network.sh
    odoo_exposure.sh
    docker_containment.sh
    odoo_defaults.sh
    rollback.sh
    remediate_existing.sh
    critical_gate.sh
    firewall.sh
    firewall_ufw.sh
    firewall_firewalld.sh
    firewall_nftables.sh
    docker_firewall.sh
    nginx_edge.sh
    cloudflare.sh
    edge.sh
    ssh.sh
    brute_force.sh
    management_surface.sh
    host_baseline.sh
    persistence_audit.sh
    s2_rollback.sh
    s2_gate.sh
    legacy_bridge.sh
  )

  if [[ -z "$root" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
      root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    fi
  fi
  [[ -n "$root" ]] || return 1

  for mod in "${mods[@]}"; do
    local f="$root/src/security/platform/$mod"
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      source "$f"
    fi
  done
  return 0
}
