# shellcheck shell=bash
# Security Gate S5 — reboot / service-restart requirement detection.

soviez_s5_detect_reboot_required() {
  local marker="${SOVIEZ_S5_REBOOT_MARKER:-/var/run/reboot-required}"
  if [[ -f "$marker" ]]; then
    echo REQUIRED
    return 0
  fi
  # Optional Debian packages listing pending reboot reasons.
  if [[ -d /var/run/reboot-required.d ]] && compgen -G '/var/run/reboot-required.d/*' >/dev/null 2>&1; then
    echo REQUIRED
    return 0
  fi
  echo NOT_REQUIRED
  return 0
}

soviez_s5_detect_service_restart_required() {
  if [[ "${SOVIEZ_S5_INJECT_NEEDRESTART:-}" == "UNKNOWN" ]]; then
    echo UNKNOWN
    return 0
  fi
  if [[ -n "${SOVIEZ_S5_INJECT_NEEDRESTART:-}" ]]; then
    printf '%s\n' "$SOVIEZ_S5_INJECT_NEEDRESTART"
    return 0
  fi

  if command -v needrestart >/dev/null 2>&1; then
    # -b batch, -r l list mode; non-zero often means restarts pending.
    local out rc=0
    out="$(needrestart -b -r l 2>/dev/null || true)"
    if printf '%s' "$out" | grep -Eqi 'NEEDRESTART-SVC:|NEEDRESTART-KCUR:|NEEDRESTART-KEXP:'; then
      if printf '%s' "$out" | grep -Eqi 'NEEDRESTART-SVC:'; then
        echo REQUIRED
        return 0
      fi
    fi
    # Kernel mismatch via needrestart batch keys.
    local kcur kexp
    kcur="$(printf '%s\n' "$out" | awk -F: '/NEEDRESTART-KCUR/{print $2}' | tr -d ' ')"
    kexp="$(printf '%s\n' "$out" | awk -F: '/NEEDRESTART-KEXP/{print $2}' | tr -d ' ')"
    if [[ -n "$kcur" && -n "$kexp" && "$kcur" != "$kexp" ]]; then
      echo REQUIRED
      return 0
    fi
    echo NOT_REQUIRED
    return 0
  fi

  echo UNKNOWN
  return 0
}
