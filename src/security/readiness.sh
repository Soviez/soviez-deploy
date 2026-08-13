# shellcheck shell=bash
# Phase 24 — Phase 25 readiness (informational; not authorization).

soviez_security_phase25_readiness() {
  local status="PASS"
  local warnings=()
  local blockers=()
  local sha ver
  ver="$(soviez_version 2>/dev/null || echo unknown)"
  if [[ -f "${SOVIEZ_SH_ROOT:-}/dist/soviez.sh" ]]; then
    sha="$(shasum -a 256 "${SOVIEZ_SH_ROOT}/dist/soviez.sh" | awk '{print $1}')"
  elif [[ -f dist/soviez.sh ]]; then
    sha="$(shasum -a 256 dist/soviez.sh | awk '{print $1}')"
  else
    sha="missing"
    blockers+=("dist_missing")
    status="BLOCKED"
  fi

  local dist_art=""
  if [[ -f "${SOVIEZ_SH_ROOT:-}/dist/soviez.sh" ]]; then
    dist_art="${SOVIEZ_SH_ROOT}/dist/soviez.sh"
  elif [[ -f dist/soviez.sh ]]; then
    dist_art="dist/soviez.sh"
  fi
  if [[ -n "$dist_art" ]]; then
    if ! soviez_security_scan_dist "$dist_art" >/dev/null 2>&1; then
      blockers+=("dist_secret_scan")
      status="BLOCKED"
    fi
  fi

  # Soft warning if Phase 11.5 visual still deferred (does not block)
  warnings+=("phase11_5_visual_acceptance_deferred")

  local ttl_hours=24
  local generated
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local expires
  expires="$(date -u -v+${ttl_hours}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${ttl_hours} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "$generated")"

  echo "READY FOR PHASE 25 — $status"
  echo "Phase 25 remains UNAUTHORIZED"
  echo "installer_version=$ver"
  echo "artifact_sha256=$sha"
  echo "generated_at=$generated"
  echo "expires_at=$expires"
  echo "ttl_hours=$ttl_hours"
  echo "invalidate_on=artifact_sha_change,signing_trust_change,secret_scan_failure,test_bypass_regression,registry_credential_persistence,ticket_replay_regression,security_test_failure"
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "warnings=${warnings[*]}"
  fi
  if [[ ${#blockers[@]} -gt 0 ]]; then
    echo "blockers=${blockers[*]}"
  fi
  [[ "$status" != "BLOCKED" ]]
}

soviez_cmd_security_phase25_readiness() {
  soviez_security_phase25_readiness
}

soviez_cmd_security_scan() {
  local root="${SOVIEZ_SH_ROOT:-.}"
  [[ -d "$root/src" ]] || root="$(pwd)"
  if [[ -x "$root/tools/secret_scan.sh" ]]; then
    bash "$root/tools/secret_scan.sh" all
  else
    soviez_security_scan_tree "$root"
    soviez_security_scan_dist "$root/dist/soviez.sh"
  fi
}

soviez_cmd_security_status() {
  echo "STRICT_SIG=${SOVIEZ_UPDATE_STRICT_SIG:-1}"
  echo "PHASE24_CERTIFICATION=${SOVIEZ_PHASE24_CERTIFICATION:-0}"
  echo "test_bypass_allowed=$(soviez_security_test_bypass_allowed && echo yes || echo no)"
  echo "disposable_env=$(soviez_security_is_disposable_env && echo yes || echo no)"
}
