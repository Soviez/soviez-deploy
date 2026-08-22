# shellcheck shell=bash
# Canonical host bootstrap for `soviez.sh --init`.

soviez_host_require_root() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    return 0
  fi
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "[error] --init requires root" >&2
    return 1
  fi
}

soviez_host_assert_ubuntu_lts() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    return 0
  fi
  [[ -r /etc/os-release ]] || {
    echo "[error] cannot read /etc/os-release" >&2
    return 1
  }
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || {
    echo "[error] supported OS: Ubuntu LTS only (found ${ID:-unknown})" >&2
    return 1
  }
  case "${VERSION_ID:-}" in
    22.04|24.04) return 0 ;;
    *)
      echo "[error] supported Ubuntu LTS: 22.04 or 24.04 (found ${VERSION_ID:-unknown})" >&2
      return 1
      ;;
  esac
}

soviez_host_apt_update() {
  export DEBIAN_FRONTEND=noninteractive
  if declare -F soviez_security_apt_wait_locks >/dev/null 2>&1; then
    soviez_security_apt_wait_locks || return 1
  elif declare -F soviez_s5_apt_wait_for_lock >/dev/null 2>&1; then
    soviez_s5_apt_wait_for_lock || return 1
  fi
  apt-get update -y
}

soviez_host_apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  if declare -F soviez_security_apt_wait_locks >/dev/null 2>&1; then
    soviez_security_apt_wait_locks || return 1
  fi
  apt-get install -y "$@"
}

soviez_host_install_docker() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "[ok] Docker already installed"
    return 0
  fi
  soviez_host_apt_install ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
    >/etc/apt/sources.list.d/docker.list
  soviez_host_apt_update
  soviez_host_apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

soviez_host_install_nginx_stack() {
  if ! command -v nginx >/dev/null 2>&1; then
    soviez_host_apt_install nginx
  fi
  systemctl enable --now nginx
  if ! command -v certbot >/dev/null 2>&1; then
    soviez_host_apt_install certbot python3-certbot-nginx
  fi
}

soviez_host_install_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    soviez_host_apt_install ufw
  fi
}

soviez_host_install_fail2ban() {
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    soviez_host_apt_install fail2ban
  fi
  systemctl enable --now fail2ban 2>/dev/null || true
}

soviez_host_unattended_upgrades() {
  soviez_host_apt_install unattended-upgrades apt-listchanges || true
  if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    :
  else
    cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
  fi
  if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
    grep -q 'origin=Ubuntu,archive=.*-security' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
  fi
}

soviez_host_apparmor_validate() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    echo "[skip] AppArmor validation (test mode)"
    return 0
  fi
  if command -v aa-status >/dev/null 2>&1; then
    if aa-status --enabled 2>/dev/null | grep -qi 'not enabled'; then
      echo "[error] AppArmor must remain enabled" >&2
      return 1
    fi
    echo "[ok] AppArmor enabled"
    return 0
  fi
  echo "[warn] aa-status unavailable"
  return 0
}

soviez_host_ensure_layout() {
  mkdir -p /var/soviez/tenant /var/soviez/backups /var/soviez/tuning /var/soviez/security
  mkdir -p /opt/soviez/platform/current /opt/soviez/platform/previous /opt/soviez/platform/candidates
}

soviez_host_never_webmin() {
  if declare -F soviez_mgmt_classify_webmin >/dev/null 2>&1; then
    local wc
    wc="$(soviez_mgmt_classify_webmin)"
    case "$wc" in
      FAIL|WARNING)
        echo "[warn] Webmin/Virtualmin detected — Soviez never installs these; audit only"
        ;;
    esac
  fi
  if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | grep -q ':10000'; then
    echo "[warn] port 10000 listening — review Webmin exposure"
  fi
}

soviez_host_bootstrap_run() {
  soviez_host_require_root || return 1
  soviez_host_assert_ubuntu_lts || return 1
  export DEBIAN_FRONTEND=noninteractive

  echo "=== Soviez host initialization ==="
  soviez_host_ensure_layout
  soviez_host_apt_update || return 1
  soviez_host_apt_install curl ca-certificates gnupg lsb-release python3 jq || return 1
  soviez_host_install_docker || return 1
  soviez_host_install_nginx_stack || return 1
  soviez_host_install_ufw || return 1
  soviez_host_install_fail2ban || return 1
  soviez_host_unattended_upgrades || true

  export SOVIEZ_FW_APPLY=1
  export SOVIEZ_CLAMAV_AUTO_INSTALL=1
  if declare -F soviez_sec_s2_harden >/dev/null 2>&1; then
    soviez_sec_s2_harden || return 1
  fi

  if declare -F soviez_clamav_init_baseline >/dev/null 2>&1; then
    soviez_clamav_init_baseline || return 1
  fi

  if declare -F soviez_host_record_baseline >/dev/null 2>&1; then
    soviez_host_record_baseline "/var/soviez/security/host-baseline"
  fi

  soviez_host_apparmor_validate || return 1
  soviez_host_never_webmin

  if declare -F soviez_platform_install_self_payload >/dev/null 2>&1 \
    && [[ -f "${SOVIEZ_PLATFORM_INSTALL_SRC:-${0:-}}" ]]; then
    soviez_platform_install_self_payload 2>/dev/null || true
  fi

  echo "[ok] host initialization complete"
  return 0
}
