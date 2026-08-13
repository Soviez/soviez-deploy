# shellcheck shell=bash
# Security Gate S2 — brute-force protection (Fail2Ban preferred; CrowdSec optional OD).

soviez_bf_detect() {
  local have_f2b=0 have_crowd=0
  command -v fail2ban-client >/dev/null 2>&1 && have_f2b=1
  command -v cscli >/dev/null 2>&1 && have_crowd=1
  if [[ "$have_f2b" -eq 1 ]]; then
    printf '%s\n' "fail2ban"
  elif [[ "$have_crowd" -eq 1 ]]; then
    printf '%s\n' "crowdsec"
  else
    printf '%s\n' "none"
  fi
}

soviez_bf_fail2ban_jail_path() {
  printf '%s\n' "${SOVIEZ_FAIL2BAN_JAIL:-/etc/fail2ban/jail.d/soviez-s2.local}"
}

soviez_bf_ensure_fail2ban_ssh() {
  # Idempotent Soviez-owned jail.local fragment — SSH only by default.
  # Do NOT add fragile Odoo JSON-RPC ban jails.
  local path
  path="$(soviez_bf_fail2ban_jail_path)"
  if [[ "${SOVIEZ_BF_INSTALL:-0}" == "1" ]] && ! command -v fail2ban-client >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      if declare -F soviez_s5_apt_wait_for_lock >/dev/null 2>&1; then
        soviez_s5_apt_wait_for_lock >/dev/null 2>&1 || {
          echo "[error] security:PKG_LOCK_TIMEOUT: cannot install fail2ban while apt locked" >&2
          return 1
        }
      fi
      apt-get install -y fail2ban >/dev/null 2>&1 || true
    fi
  fi
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]] && grep -q 'SOVIEZ_OWNED' "$path" 2>/dev/null; then
    return 0
  fi
  cat >"$path" <<'EOF'
# SOVIEZ_OWNED fail2ban — Security Gate S2
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
maxretry = 5

# nginx-http-auth only — NOT Odoo /web/dataset RPC (false-positive risk)
[nginx-http-auth]
enabled = true
port    = http,https
filter  = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 5
EOF
  chmod 644 "$path"
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo "[security] Fail2Ban not present — jail file written; service enable deferred" >&2
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now fail2ban >/dev/null 2>&1 || true
    systemctl reload fail2ban >/dev/null 2>&1 || systemctl restart fail2ban >/dev/null 2>&1 || true
  fi
}

soviez_bf_decision_record() {
  # OD-SEC-04: keep Fail2Ban; CrowdSec optional — do not replace working Fail2Ban.
  local d
  d="$(soviez_bf_detect)"
  case "$d" in
    fail2ban) printf '%s\n' "KEEP_FAIL2BAN" ;;
    crowdsec) printf '%s\n' "CROWDSEC_PRESENT_OPTIONAL" ;;
    none) printf '%s\n' "NONE_NEEDS_ACTION" ;;
  esac
}
