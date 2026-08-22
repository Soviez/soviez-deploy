# shellcheck shell=bash
# Read-only platform health diagnosis.

soviez_cmd_doctor_run() {
  local rc=0 section=0
  _doc() {
    section=$((section + 1))
    printf '\n## %s\n' "$1"
  }
  _chk() {
    local name="$1" status="$2" detail="${3:-}"
    printf '%-28s %s' "$name" "$status"
    [[ -n "$detail" ]] && printf '  (%s)' "$detail"
    printf '\n'
    case "$status" in
      FAIL|NEEDS_ACTION) rc=1 ;;
    esac
  }

  echo "=== Soviez.sh Doctor (read-only) ==="
  echo "platform=$(soviez_version 2>/dev/null || echo unknown)"

  _doc "Host"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    _chk "OS" "PASS" "${PRETTY_NAME:-unknown}"
  else
    _chk "OS" "SKIP"
  fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    _chk "Docker" "PASS"
  else
    _chk "Docker" "FAIL" "daemon unavailable"
  fi

  _doc "Platform"
  local payload
  payload="$(soviez_platform_payload 2>/dev/null || echo missing)"
  if [[ -f "$payload" ]]; then
    _chk "Platform payload" "PASS" "$payload"
  else
    _chk "Platform payload" "FAIL" "not installed"
  fi

  _doc "Security controls"
  if declare -F soviez_fw_detect_backend >/dev/null 2>&1; then
    local fb
    fb="$(soviez_fw_detect_backend 2>/dev/null || echo UNKNOWN)"
    if [[ "$fb" != "UNKNOWN" ]]; then _chk "Firewall backend" "PASS" "$fb"; else _chk "Firewall backend" "FAIL"; fi
  fi
  if command -v aa-status >/dev/null 2>&1; then
    if aa-status --enabled 2>/dev/null | grep -qi 'not enabled'; then
      _chk "AppArmor" "FAIL" "disabled"
    else
      _chk "AppArmor" "PASS"
    fi
  else
    _chk "AppArmor" "SKIP"
  fi
  if command -v fail2ban-client >/dev/null 2>&1; then
    if fail2ban-client ping >/dev/null 2>&1; then _chk "Fail2Ban" "PASS"; else _chk "Fail2Ban" "FAIL"; fi
  else
    _chk "Fail2Ban" "SKIP"
  fi
  if declare -F soviez_clamav_operational_status >/dev/null 2>&1; then
    local cs
    cs="$(soviez_clamav_operational_status)"
    _chk "ClamAV" "$cs"
  elif declare -F soviez_clamav_daemon_status >/dev/null 2>&1; then
    local ds
    ds="$(soviez_clamav_daemon_status)"
    [[ "$ds" == active ]] && _chk "ClamAV daemon" "PASS" || _chk "ClamAV daemon" "FAIL" "$ds"
  fi

  _doc "Resources"
  if declare -F soviez_sizing_detect_ram_mb >/dev/null 2>&1; then
    _chk "RAM (MB)" "INFO" "$(soviez_sizing_detect_ram_mb)"
    _chk "CPU" "INFO" "$(soviez_sizing_detect_cpu)"
  fi

  _doc "Environments"
  local tdir="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}"
  local n
  n="$(find "$tdir" -name identity.json 2>/dev/null | wc -l | tr -d ' ')"
  _chk "Production count" "INFO" "$n"

  echo ""
  echo "doctor_exit=$rc"
  return "$rc"
}
