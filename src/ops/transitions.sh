# shellcheck shell=bash

SOVIEZ_OPS_STATES=(created queued starting running waiting retry_scheduled cancel_requested canceling rollback_running recovery_required completed canceled failed_retryable failed_terminal)

soviez_ops_sm_can_transition() {
  local from="$1" to="$2"
  [[ "$from" == "$to" ]] && return 0
  case "$from:$to" in
    created:queued|created:starting|created:canceled|created:failed_*|queued:starting|queued:cancel_requested|queued:canceled|queued:failed_*|starting:running|starting:waiting|starting:failed_*|starting:recovery_required|starting:canceled|running:waiting|running:retry_scheduled|running:cancel_requested|running:rollback_running|running:recovery_required|running:completed|running:failed_*|waiting:running|waiting:retry_scheduled|waiting:cancel_requested|waiting:canceled|waiting:recovery_required|waiting:completed|waiting:failed_*|retry_scheduled:starting|retry_scheduled:running|retry_scheduled:cancel_requested|retry_scheduled:canceled|retry_scheduled:failed_*|failed_retryable:retry_scheduled|failed_retryable:canceled|cancel_requested:canceling|cancel_requested:canceled|cancel_requested:recovery_required|canceling:canceled|canceling:rollback_running|canceling:recovery_required|rollback_running:canceled|rollback_running:completed|rollback_running:recovery_required|rollback_running:failed_*|recovery_required:starting|recovery_required:running|recovery_required:canceled|recovery_required:failed_terminal|recovery_required:retry_scheduled) return 0 ;;
  esac
  return 1
}
soviez_ops_sm_assert() { soviez_ops_sm_can_transition "$1" "$2" || soviez_ops_die OPERATION_TRANSITION_INVALID "Illegal transition: $1 -> $2"; }

soviez_ops_transition() {
  local op_id="$1" new_state="$2" checkpoint="${3:-}" meta_json="${4:-{}}" path current updated
  path="$(soviez_ops_canonical_state_path "$op_id")"
  [[ -f "$path" ]] || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  current="$(cat "$path")"; soviez_ops_validate_record "$current"
  local old_state; old_state="$(soviez_json_get "$current" current_state)"
  soviez_ops_sm_assert "$old_state" "$new_state"
  updated="$(SOVIEZ_CURRENT="$current" SOVIEZ_STATE="$new_state" SOVIEZ_CHECKPOINT="$checkpoint" SOVIEZ_META="$meta_json" python3 - <<'PY'
import json, os, time
d=json.loads(os.environ["SOVIEZ_CURRENT"]); d["current_state"]=os.environ["SOVIEZ_STATE"]
if os.environ["SOVIEZ_CHECKPOINT"]: d["current_checkpoint"]=os.environ["SOVIEZ_CHECKPOINT"]
try:
    meta=json.loads(os.environ["SOVIEZ_META"])
    if not isinstance(d.get("meta"), dict): d["meta"]={}
    d["meta"].update(meta)
except Exception:
    pass
d["previous_state"]=d.get("current_state")
d["sequence"]=int(d.get("sequence") or 0)+1
d["updated_at"]=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())
d["state_entered_at"]=d["updated_at"]
print(json.dumps(d,separators=(",",":")))
PY
)"
  # Fix previous_state before overwrite — recompute properly
  updated="$(SOVIEZ_CURRENT="$current" SOVIEZ_NEW="$updated" python3 - <<'PY'
import json, os
old=json.loads(os.environ["SOVIEZ_CURRENT"]); new=json.loads(os.environ["SOVIEZ_NEW"])
new["previous_state"]=old.get("current_state")
print(json.dumps(new,separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$path" "$updated"
  soviez_ops_append_event "$op_id" "transition" "$old_state -> $new_state" "$meta_json"
  soviez_ops_registry_register "$op_id" 2>/dev/null || true
  case "$new_state" in completed|canceled|failed_terminal) soviez_ops_history_append "$op_id" 2>/dev/null || true ;; esac
}
