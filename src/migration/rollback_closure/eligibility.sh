# shellcheck shell=bash

soviez_migration_rollback_window_close_eligibility() {
  local cutover_id="${1:-}"
  soviez_migration_p22_paths_init
  local blockers=() warnings=()

  # Already closed?
  local byc
  byc="$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
  if [[ -f "$byc" ]]; then
    local closed
    closed="$(soviez_json_get "$(cat "$byc")" automatic_rollback_allowed 2>/dev/null || echo true)"
    if [[ "$closed" == "False" || "$closed" == "false" ]]; then
      printf '{"eligible":false,"code":"MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED","reason":"already_closed"}\n'
      return 1
    fi
  fi

  # Stabilization PASS required.
  local stab
  set +e
  stab="$(soviez_migration_stabilization_latest_report "$cutover_id" 2>/dev/null)"
  local src=$?
  set -e
  if [[ "$src" -ne 0 ]]; then
    blockers+=("stabilization_required")
  else
    [[ "$(soviez_json_get "$stab" stabilization_status)" == "PASS" ]] || blockers+=("stabilization_not_pass")
  fi

  # Window must be expired (immediate window 30m / P21 rollback window).
  local wf
  wf="$(soviez_migration_cutover_rollback_window_path "$cutover_id")"
  if [[ -f "$wf" ]]; then
    local exp
    exp="$(soviez_json_get "$(cat "$wf")" expires_at)"
    if ! soviez_migration_p22_is_expired_at "$exp"; then
      # Allow fixture force-expire
      if [[ "${SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED:-0}" == "1" ]]; then
        :
      else
        blockers+=("window_still_open")
      fi
    fi
  else
    blockers+=("window_missing")
  fi

  # No active incident.
  if [[ "${SOVIEZ_MIG_P22_INJECT_INCIDENT:-0}" == "1" ]]; then
    blockers+=("active_incident")
  fi

  # No active rollback in progress.
  if [[ "${SOVIEZ_MIG_P22_ACTIVE_ROLLBACK:-0}" == "1" ]]; then
    blockers+=("active_rollback")
  fi

  # Backups valid (fixture defaults ok unless injected).
  if [[ "${SOVIEZ_MIG_P22_INJECT_BACKUPS_FAIL:-0}" == "1" ]]; then
    blockers+=("backups_invalid")
  fi

  if [[ ${#blockers[@]} -gt 0 ]]; then
    SOVIEZ_BL="$(printf '%s,' "${blockers[@]}")" python3 - <<'PY'
import json, os
bl=[x for x in os.environ.get("SOVIEZ_BL","").split(",") if x]
code="MIGRATION_ROLLBACK_WINDOW_CLOSE_DENIED"
if "window_still_open" in bl:
  code="MIGRATION_ROLLBACK_WINDOW_STILL_REQUIRED"
elif "active_incident" in bl:
  code="MIGRATION_ACTIVE_INCIDENT_BLOCKS_ARCHIVE"
elif "stabilization_required" in bl or "stabilization_not_pass" in bl:
  code="MIGRATION_STABILIZATION_REQUIRED"
print(json.dumps({"eligible":False,"code":code,"blockers":bl}, separators=(",", ":")))
PY
    return 1
  fi
  printf '{"eligible":true,"warnings":[]}\n'
  return 0
}
