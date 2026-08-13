# shellcheck shell=bash
# Certification clock for Phase 22 stabilization duration tests.
# Production: always real system time. Override ONLY when both fixture flags set.

soviez_migration_p22_now_epoch() {
  if [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "${SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK:-0}" == "1" ]]; then
    if [[ -n "${SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH:-}" ]]; then
      printf '%s\n' "$SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH"
      return 0
    fi
  elif [[ -n "${SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH:-}" ]]; then
    # Production (or fixture without allow): deny clock override.
    if [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" != "1" || "${SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_PHASE22_CERT_CLOCK_DENIED \
        "SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH denied outside fixture+allow flags"
    fi
  fi
  soviez_migration_now_epoch
}

soviez_migration_p22_now_iso() {
  local epoch
  epoch="$(soviez_migration_p22_now_epoch)"
  python3 -c "import datetime,sys; print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$epoch"
}

soviez_migration_p22_clock_source() {
  if [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "${SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK:-0}" == "1" && -n "${SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH:-}" ]]; then
    printf 'certification_override\n'
  else
    printf 'system\n'
  fi
}

soviez_migration_p22_advance_cert_clock() {
  local delta="${1:-0}"
  [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "${SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK:-0}" == "1" ]] || \
    soviez_migration_die MIGRATION_PHASE22_CERT_CLOCK_DENIED "cert clock advance requires fixture+allow"
  local now
  now="$(soviez_migration_p22_now_epoch)"
  export SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH=$((now + delta))
}

soviez_migration_p22_is_expired_at() {
  local expires_iso="$1"
  local now exp
  now="$(soviez_migration_p22_now_epoch)"
  exp="$(soviez_migration_iso_to_epoch "$expires_iso")" || return 0
  [[ "$now" -ge "$exp" ]]
}
