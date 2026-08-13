# shellcheck shell=bash
# Phase 24 — Registry / Docker auth hygiene.

soviez_security_registry_assert_temp_config_clean() {
  local cfg="${1:-}"
  if [[ -n "$cfg" && -d "$cfg" ]]; then
    soviez_security_die SECURITY_REGISTRY_CREDENTIAL_PERSISTED "temp DOCKER_CONFIG still present"
  fi
  return 0
}

soviez_security_registry_assert_no_global_auth_for() {
  local registry="${1:-}"
  [[ -n "$registry" ]] || return 0
  local conf="${HOME}/.docker/config.json"
  [[ -f "$conf" ]] || return 0
  # If global config still contains our registry auth after ephemeral session, fail when required.
  if grep -q "$registry" "$conf" 2>/dev/null; then
    if [[ "${SOVIEZ_PHASE24_REQUIRE_REGISTRY_CLEAN:-0}" == "1" || "${SOVIEZ_PHASE24_CERTIFICATION:-0}" == "1" ]]; then
      # Only fail if auths block present for that host (not mere string in unrelated field)
      if python3 - "$conf" "$registry" <<'PY' 2>/dev/null
import json,sys
p,reg=sys.argv[1],sys.argv[2]
try:
  d=json.load(open(p))
except Exception:
  sys.exit(0)
auths=d.get("auths") or {}
for k in auths:
  if reg in k or k in reg:
    sys.exit(1)
sys.exit(0)
PY
      then
        :
      else
        soviez_security_die SECURITY_REGISTRY_CREDENTIAL_PERSISTED "global docker auth retains $registry"
      fi
    fi
  fi
  return 0
}
