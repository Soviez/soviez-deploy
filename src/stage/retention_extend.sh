# shellcheck shell=bash
# Phase 13 — retention extension is total lifetime from immutable creation.

soviez_retention_extend() {
  local stage_id="$1" total_days="$2" yes_flag="${3:-}" rec current status created proposed max current_days
  soviez_retention_ensure "$stage_id"
  [[ "$total_days" =~ ^[0-9]+$ ]] || soviez_retention_die RETENTION_EXTENSION_INVALID "Retention days must be an integer"
  rec="$(soviez_retention_read "$stage_id")"
  status="$(soviez_json_get "$rec" retention_status)"
  [[ "$status" != "deleted" && "$status" != "deleting" && "$status" != "deletion_started" ]] || soviez_retention_die RETENTION_EXTENSION_TOO_LATE "Deletion has started"
  [[ ! -d "$(soviez_retention_lock_dir "$stage_id")" ]] || soviez_retention_die RETENTION_DELETION_LOCKED "Retention deletion is locked"
  current_days="$(soviez_json_get "$rec" requested_extension_days)"
  [[ "$total_days" -ge "$current_days" ]] || soviez_retention_die RETENTION_EXTENSION_REDUCES_DEADLINE "Extensions cannot reduce retention"
  [[ "$total_days" -le "$SOVIEZ_RETENTION_MAXIMUM_DAYS" ]] || soviez_retention_die RETENTION_MAXIMUM_EXCEEDED "Maximum retention is $SOVIEZ_RETENTION_MAXIMUM_DAYS days"
  if [[ "$total_days" -eq "$current_days" ]]; then soviez_retention_ok RETENTION_EXTENSION_AVAILABLE "Retention already set to $total_days days"; return 0; fi
  if [[ "$yes_flag" != "--yes" && "${SOVIEZ_RETENTION_EXTEND_CONFIRM:-}" != "$stage_id" ]]; then
    if [[ ! -t 0 ]]; then soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Set SOVIEZ_RETENTION_EXTEND_CONFIRM=$stage_id or pass --yes"; fi
    printf 'Type the Stage ID to confirm a %s-day total retention lifetime: ' "$total_days" >&2
    local typed; read -r typed; [[ "$typed" == "$stage_id" ]] || soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Confirmation mismatch"
  fi
  created="$(soviez_json_get "$rec" created_at)"
  proposed="$(soviez_retention_add_calendar_days_utc "$created" "$total_days")"
  max="$(soviez_json_get "$rec" maximum_retention_deadline)"
  [[ "$(soviez_retention_parse_utc_epoch "$proposed")" -le "$(soviez_retention_parse_utc_epoch "$max")" ]] || soviez_retention_die RETENTION_MAXIMUM_EXCEEDED "Requested deadline exceeds immutable maximum"
  soviez_retention_patch "$stage_id" "$(SOVIEZ_DAYS="$total_days" SOVIEZ_DEADLINE="$proposed" python3 - <<'PY'
import json, os
print(json.dumps({"requested_extension_days":int(os.environ["SOVIEZ_DAYS"]),"current_retention_deadline":os.environ["SOVIEZ_DEADLINE"],"retention_status":"active","last_failure_code":None},separators=(",",":")))
PY
)"
  soviez_retention_refresh_derived "$stage_id"
  soviez_retention_ok RETENTION_EXTENSION_AVAILABLE "Retention lifetime set to $total_days days"
}
