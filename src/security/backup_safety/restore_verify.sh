# shellcheck shell=bash
# Security Gate S5 — restore verification requires S4 for untrusted sources.

soviez_s5_restore_verify_requires_s4() {
  local trust="${1:-${SOVIEZ_Q_TRUST:-${SOVIEZ_S5_RESTORE_TRUST:-EXTERNAL_UNKNOWN}}}"
  case "$trust" in
    TRUSTED_SOVIEZ|TRUSTED_INTERNAL|PRODUCTION_SELF)
      echo false
      return 1
      ;;
    *)
      # Untrusted / unknown / incident → S4 quarantine mandatory.
      echo true
      return 0
      ;;
  esac
}

soviez_s5_restore_verify() {
  local archive_or_dir="$1"
  local trust="${2:-${SOVIEZ_S5_RESTORE_TRUST:-EXTERNAL_UNKNOWN}}"

  if [[ -z "$archive_or_dir" ]]; then
    echo FAIL
    return 1
  fi

  local needs_s4
  needs_s4="$(soviez_s5_restore_verify_requires_s4 "$trust")"
  if [[ "$needs_s4" == "true" ]]; then
    if ! declare -F soviez_security_validate_quarantine >/dev/null 2>&1 \
      && ! declare -F soviez_q_create >/dev/null 2>&1; then
      echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: S4 unavailable for untrusted restore" >&2
      echo FAIL
      return 1
    fi
    # Wrap: create/use quarantine and run S4 validation when available.
    local qid="${SOVIEZ_Q_ACTIVE_ID:-}"
    if [[ -z "$qid" ]] && declare -F soviez_q_create >/dev/null 2>&1; then
      export SOVIEZ_Q_TRUST="$trust"
      qid="$(soviez_q_create)"
      export SOVIEZ_Q_ACTIVE_ID="$qid"
    fi
    if declare -F soviez_security_validate_quarantine >/dev/null 2>&1; then
      if soviez_security_validate_quarantine "$qid" >/dev/null 2>&1; then
        echo PASS
        return 0
      fi
      echo FAIL
      return 1
    fi
    # S4 modules present but gate not invoked yet — still require quarantine id.
    if [[ -n "$qid" ]]; then
      echo PASS
      return 0
    fi
    echo FAIL
    return 1
  fi

  # Trusted path: integrity check if directory looks like a backup.
  if [[ -d "$archive_or_dir" ]] && declare -F soviez_s5_backup_integrity_verify >/dev/null 2>&1; then
    if soviez_s5_backup_integrity_verify "$archive_or_dir" >/dev/null 2>&1; then
      echo PASS
      return 0
    fi
    echo FAIL
    return 1
  fi
  echo PASS
  return 0
}
