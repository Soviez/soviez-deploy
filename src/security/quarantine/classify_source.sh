# shellcheck shell=bash
# Security Gate S4 — source trust classification.

soviez_q_classify_source() {
  local signed="${SOVIEZ_Q_BACKUP_SIGNED:-0}"
  local local_soviez="${SOVIEZ_Q_LOCAL_SOVIEZ:-0}"
  local incident="${SOVIEZ_Q_INCIDENT:-0}"
  local compromised="${SOVIEZ_Q_COMPROMISED:-0}"
  local legacy="${SOVIEZ_Q_LEGACY_ODOO:-0}"
  local sec_status="${SOVIEZ_Q_PRIOR_SECURITY_STATUS:-}"

  if [[ "$compromised" == "1" || "$sec_status" == "FAIL" ]]; then
    printf '%s\n' "COMPROMISED_CONFIRMED"; return 0
  fi
  if [[ "$incident" == "1" ]]; then
    printf '%s\n' "INCIDENT_SUSPECTED"; return 0
  fi
  if [[ "$local_soviez" == "1" && "$signed" == "1" ]]; then
    printf '%s\n' "TRUSTED_SIGNED_BACKUP"; return 0
  fi
  if [[ "$local_soviez" == "1" ]]; then
    printf '%s\n' "TRUSTED_LOCAL_SOVIEZ"; return 0
  fi
  if [[ "$legacy" == "1" ]]; then
    printf '%s\n' "LEGACY_ODOO"; return 0
  fi
  printf '%s\n' "EXTERNAL_UNKNOWN"
}

soviez_q_requires_full_quarantine() {
  local trust="${1:-EXTERNAL_UNKNOWN}"
  case "$trust" in
    TRUSTED_LOCAL_SOVIEZ|TRUSTED_SIGNED_BACKUP)
      [[ "${SOVIEZ_Q_FORCE_QUARANTINE:-0}" == "1" ]] && return 0
      return 1
      ;;
    *) return 0 ;;
  esac
}
