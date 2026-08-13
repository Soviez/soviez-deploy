# shellcheck shell=bash
# Phase 13 — durable, per-Stage retention sidecar.

soviez_retention_file() { printf '%s/retention.json\n' "$(soviez_stage_dir "$1")"; }
soviez_retention_warnings_file() { printf '%s/retention-warnings.jsonl\n' "$(soviez_stage_dir "$1")"; }
soviez_retention_banner_file() { printf '%s/config/retention-banner.txt\n' "$(soviez_stage_dir "$1")"; }
soviez_retention_banner_html_file() { printf '%s/config/retention-banner.html\n' "$(soviez_stage_dir "$1")"; }
soviez_retention_lock_dir() { printf '%s/.retention-delete.lock\n' "$(soviez_stage_dir "$1")"; }
soviez_retention_tombstone_dir() { printf '%s/retention-tombstones\n' "${SOVIEZ_ROOT:-/var/soviez}"; }
soviez_retention_tombstone_file() { printf '%s/%s.json\n' "$(soviez_retention_tombstone_dir)" "$1"; }

soviez_retention_read() {
  local file
  file="$(soviez_retention_file "$1")"
  [[ -f "$file" ]] || soviez_retention_die RETENTION_METADATA_MISSING "Missing retention metadata for Stage $1"
  python3 -m json.tool "$file" >/dev/null 2>&1 || soviez_retention_die RETENTION_METADATA_CORRUPT "Invalid retention metadata for Stage $1"
  cat "$file"
}

soviez_retention_write() {
  local stage_id="$1" json="$2" file old
  file="$(soviez_retention_file "$stage_id")"
  if [[ -f "$file" ]]; then
    old="$(cat "$file")"
    SOVIEZ_OLD="$old" SOVIEZ_NEW="$json" python3 - <<'PY' || soviez_retention_die RETENTION_METADATA_CORRUPT "Immutable retention fields changed"
import json, os, sys
old, new = json.loads(os.environ["SOVIEZ_OLD"]), json.loads(os.environ["SOVIEZ_NEW"])
for key in ("created_at", "maximum_retention_deadline"):
    if old.get(key) != new.get(key):
        sys.exit(1)
PY
  fi
  soviez_stage_inventory_atomic_write "$file" "$json"
}

soviez_retention_patch() {
  local stage_id="$1" patch="$2" current merged
  current="$(soviez_retention_read "$stage_id")"
  merged="$(SOVIEZ_CURRENT="$current" SOVIEZ_PATCH="$patch" python3 - <<'PY'
import json, os, sys
cur=json.loads(os.environ["SOVIEZ_CURRENT"]); patch=json.loads(os.environ["SOVIEZ_PATCH"])
for key in ("created_at", "maximum_retention_deadline"):
    if key in patch and patch[key] != cur.get(key):
        raise SystemExit("immutable field")
cur.update(patch)
print(json.dumps(cur, separators=(",", ":")))
PY
)" || soviez_retention_die RETENTION_METADATA_CORRUPT "Invalid retention patch"
  soviez_retention_write "$stage_id" "$merged"
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    local op_id status
    op_id="$(soviez_json_get "$merged" retention_operation_id 2>/dev/null || true)"
    status="$(soviez_json_get "$merged" retention_status 2>/dev/null || true)"
    if [[ -n "$op_id" && "$op_id" != "null" && -n "$status" && "$status" != "null" ]]; then
      if [[ "$(soviez_json_get "$merged" state 2>/dev/null || true)" != "$status" ]]; then
        merged="$(SOVIEZ_CUR="$merged" SOVIEZ_S="$status" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["state"]=os.environ["SOVIEZ_S"]
print(json.dumps(d,separators=(",",":")))
PY
)"
        soviez_retention_write "$stage_id" "$merged"
      fi
      local outcome="$status"
      case "$status" in
        deleted|tombstoned) outcome="completed" ;;
        needs_action|deletion_blocked) outcome="failed_retryable" ;;
        recovery_required) outcome="recovery_required" ;;
      esac
      soviez_ops_sync_transition "$op_id" retention_delete "$stage_id" "$outcome" "transition" "{}" "$(soviez_retention_file "$stage_id")" \
        || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_PENDING
    fi
  fi
}

soviez_retention_init_for_stage() {
  local stage_id="$1" created_at="${2:-}" identity default_deadline max_deadline json
  identity="$(soviez_stage_inventory_find "$stage_id")" || soviez_retention_die STAGE_NOT_FOUND "Unknown Stage $stage_id"
  [[ -n "$created_at" ]] || created_at="$(soviez_json_get "$identity" created_at)"
  [[ -n "$created_at" ]] || soviez_retention_die RETENTION_METADATA_CORRUPT "Stage has no immutable created_at"
  [[ -f "$(soviez_retention_file "$stage_id")" ]] && { soviez_retention_read "$stage_id"; return 0; }
  default_deadline="$(soviez_retention_add_calendar_days_utc "$created_at" "$SOVIEZ_RETENTION_DEFAULT_DAYS")"
  max_deadline="$(soviez_retention_add_calendar_days_utc "$created_at" "$SOVIEZ_RETENTION_MAXIMUM_DAYS")"
  # Ensure Nginx ownership marker when Stage nginx stubs exist under Stage config
  local cfg
  cfg="$(soviez_json_get "$identity" stage_config_path)"
  if [[ -n "$cfg" && -d "$cfg" ]]; then
    if [[ -d "$cfg/nginx" || -f "$cfg/nginx.conf" ]]; then
      printf '%s\n' "$stage_id" > "$cfg/nginx.owned"
      chmod 640 "$cfg/nginx.owned" 2>/dev/null || true
    fi
  fi
  json="$(SOVIEZ_SID="$stage_id" SOVIEZ_CREATED="$created_at" SOVIEZ_DEFAULT="$default_deadline" SOVIEZ_MAX="$max_deadline" python3 - <<'PY'
import json, os
print(json.dumps({"stage_id":os.environ["SOVIEZ_SID"],"created_at":os.environ["SOVIEZ_CREATED"],
"requested_extension_days":14,"current_retention_deadline":os.environ["SOVIEZ_DEFAULT"],
"maximum_retention_deadline":os.environ["SOVIEZ_MAX"],"retention_status":"active",
"days_remaining":None,"last_failure_code":None,"completed_deletion_steps":[],"retention_operation_id":None}, separators=(",",":")))
PY
)"
  soviez_retention_write "$stage_id" "$json"
}

soviez_retention_ensure() {
  local stage_id="$1"
  [[ -f "$(soviez_stage_identity_file "$stage_id")" ]] || soviez_retention_die STAGE_NOT_FOUND "Unknown Stage $stage_id"
  [[ -f "$(soviez_retention_file "$stage_id")" ]] || soviez_retention_init_for_stage "$stage_id"
  soviez_retention_read "$stage_id" >/dev/null
}

soviez_retention_refresh_derived() {
  local stage_id="$1" rec deadline max days status failure patch
  soviez_retention_ensure "$stage_id"
  rec="$(soviez_retention_read "$stage_id")"
  deadline="$(soviez_json_get "$rec" current_retention_deadline)"
  max="$(soviez_json_get "$rec" maximum_retention_deadline)"
  days="$(soviez_retention_days_remaining "$deadline")"
  failure="$(soviez_json_get "$rec" last_failure_code 2>/dev/null || true)"
  status="$(soviez_json_get "$rec" retention_status)"
  [[ "$(soviez_retention_parse_utc_epoch "$deadline")" -le "$(soviez_retention_parse_utc_epoch "$max")" ]] || soviez_retention_die RETENTION_MAXIMUM_EXCEEDED "Retention deadline exceeds immutable maximum"
  case "$status" in
    deleting|deleted|deletion_started|deletion_running|final_backup_running|safe_shield_validating|recovery_required)
      ;;
    needs_action|deletion_blocked)
      ;;
    *)
      if [[ -n "$failure" && "$failure" != "null" ]]; then
        if [[ "$failure" == "RETENTION_PARTIAL_DELETION" ]]; then
          status="recovery_required"
        else
          status="needs_action"
        fi
      elif [[ "$days" -le 0 ]]; then
        status="deletion_due"
      elif [[ "$deadline" == "$max" ]]; then
        status="extension_limit_reached"
      else
        status="extension_available"
      fi
      ;;
  esac
  patch="$(SOVIEZ_DAYS="$days" SOVIEZ_STATUS="$status" python3 - <<'PY'
import json, os
print(json.dumps({"days_remaining":int(os.environ["SOVIEZ_DAYS"]),"retention_status":os.environ["SOVIEZ_STATUS"]},separators=(",",":")))
PY
)"
  soviez_retention_patch "$stage_id" "$patch"
}

soviez_retention_lock_acquire() {
  local lock
  lock="$(soviez_retention_lock_dir "$1")"
  if mkdir "$lock" 2>/dev/null; then printf '%s\n' "$$" > "$lock/pid"; return 0; fi
  soviez_retention_die RETENTION_DELETION_LOCKED "Retention operation already active for Stage $1"
}
soviez_retention_lock_release() { rm -rf "$(soviez_retention_lock_dir "$1")"; }
