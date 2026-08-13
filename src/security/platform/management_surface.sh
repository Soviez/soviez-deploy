# shellcheck shell=bash
# Security Gate S2 — Webmin/Virtualmin detection (detect+report; no blind removal).

soviez_mgmt_detect_webmin() {
  local present=0 port_bind="" tls="unknown" version=""
  if command -v webmin >/dev/null 2>&1 || [[ -d /etc/webmin ]] || [[ -f /etc/webmin/miniserv.conf ]]; then
    present=1
  fi
  if systemctl list-unit-files 2>/dev/null | grep -qi webmin; then
    present=1
  fi
  if [[ -f /etc/webmin/miniserv.conf ]]; then
    port_bind="$(awk -F= '/^port=/{print $2}' /etc/webmin/miniserv.conf 2>/dev/null | head -1)"
    version="$(awk -F= '/^version=/{print $2}' /etc/webmin/version 2>/dev/null | head -1 || true)"
    if grep -qi 'ssl=1' /etc/webmin/miniserv.conf 2>/dev/null; then
      tls="yes"
    else
      tls="no"
    fi
  fi
  port_bind="${port_bind:-10000}"
  # Listening check via ss if available.
  local listen="unknown"
  if command -v ss >/dev/null 2>&1; then
    if ss -lnt 2>/dev/null | grep -Eq ":${port_bind}\\b"; then
      listen="listening"
      if ss -lnt 2>/dev/null | grep -E "0\\.0\\.0\\.0:${port_bind}|\\*:${port_bind}|:::${port_bind}"; then
        listen="public"
      elif ss -lnt 2>/dev/null | grep -Eq "127\\.0\\.0\\.1:${port_bind}|\\[::1\\]:${port_bind}"; then
        listen="localhost"
      fi
    else
      listen="not_listening"
    fi
  fi
  printf 'present=%s port=%s listen=%s tls=%s version=%s\n' \
    "$present" "$port_bind" "$listen" "$tls" "${version:-unknown}"
}

soviez_mgmt_detect_virtualmin() {
  local present=0
  if command -v virtualmin >/dev/null 2>&1 || [[ -d /etc/webmin/virtual-server ]] || \
     [[ -f /usr/sbin/virtualmin ]]; then
    present=1
  fi
  printf 'present=%s\n' "$present"
}

soviez_mgmt_classify_webmin() {
  # N/A | PASS | WARNING | FAIL
  local info
  info="$(soviez_mgmt_detect_webmin)"
  local present listen tls
  present="$(printf '%s' "$info" | sed -n 's/.*present=\([0-9]*\).*/\1/p')"
  listen="$(printf '%s' "$info" | sed -n 's/.*listen=\([^ ]*\).*/\1/p')"
  tls="$(printf '%s' "$info" | sed -n 's/.*tls=\([^ ]*\).*/\1/p')"
  if [[ "$present" != "1" ]]; then
    printf '%s\n' "N/A"
    return 0
  fi
  case "$listen" in
    public)
      if [[ "$tls" == "no" ]]; then
        printf '%s\n' "FAIL"
      else
        printf '%s\n' "WARNING"
      fi
      ;;
    localhost) printf '%s\n' "PASS" ;;
    *) printf '%s\n' "WARNING" ;;
  esac
}
