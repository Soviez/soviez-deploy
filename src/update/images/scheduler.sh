# shellcheck shell=bash

soviez_image_cleanup_schedule() {
  local update_op_id="$1" production_id="$2" current_digest="$3" rollback_digest="$4"
  soviez_image_cleanup_paths_init
  local op_id="imgclean-${update_op_id}"
  local dir="$SOVIEZ_IMAGE_CLEANUP_DIR/operations/$op_id"
  mkdir -p "$dir"
  SOVIEZ_OP="$op_id" SOVIEZ_UPD="$update_op_id" SOVIEZ_T="$production_id" \
  SOVIEZ_C="$current_digest" SOVIEZ_R="$rollback_digest" SOVIEZ_NOW="$(soviez_utc_now)" \
  SOVIEZ_H="${SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS:-24}" python3 - <<'PY' > "$dir/state.json"
import json,os
from datetime import datetime,timedelta,timezone
now=datetime.now(timezone.utc)
hours=int(os.environ["SOVIEZ_H"])
print(json.dumps({
  "operation_id":os.environ["SOVIEZ_OP"],
  "operation_type":"update_image_cleanup",
  "parent_update_operation_id":os.environ["SOVIEZ_UPD"],
  "environment_id":os.environ["SOVIEZ_T"],
  "current_state":"scheduled",
  "checkpoint":"waiting_safety_window",
  "current_digest":os.environ["SOVIEZ_C"],
  "rollback_digest":os.environ["SOVIEZ_R"],
  "not_before":(now+timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "created_at":os.environ["SOVIEZ_NOW"],
},separators=(",",":")))
PY
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" update_image_cleanup "$production_id" "$dir/state.json" 2>/dev/null || true
  fi
  printf '%s\n' "$op_id"
}

soviez_image_cleanup_scheduler_tick() {
  soviez_image_cleanup_paths_init
  local dir op state not_before
  for dir in "$SOVIEZ_IMAGE_CLEANUP_DIR/operations"/*; do
    [[ -d "$dir" ]] || continue
    [[ -f "$dir/state.json" ]] || continue
    state="$(soviez_json_get "$(cat "$dir/state.json")" current_state)"
    [[ "$state" == "scheduled" || "$state" == "retry_scheduled" ]] || continue
    not_before="$(soviez_json_get "$(cat "$dir/state.json")" not_before)"
    SOVIEZ_NB="$not_before" SOVIEZ_FORCE="${SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED:-0}" python3 - <<'PY' || continue
import os,sys
from datetime import datetime,timezone
if os.environ.get("SOVIEZ_FORCE")=="1":
  sys.exit(0)
nb=os.environ.get("SOVIEZ_NB") or ""
try:
  dt=datetime.fromisoformat(nb.replace("Z","+00:00"))
except Exception:
  sys.exit(1)
sys.exit(0 if datetime.now(timezone.utc)>=dt else 1)
PY
    op="$(basename "$dir")"
    local prod cur rb
    prod="$(soviez_json_get "$(cat "$dir/state.json")" environment_id)"
    cur="$(soviez_json_get "$(cat "$dir/state.json")" current_digest)"
    rb="$(soviez_json_get "$(cat "$dir/state.json")" rollback_digest)"
    # Abort if new update started for same env
    if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
      if ! soviez_ops_conflict_check update_image_cleanup "$prod" "env:$prod" 2>/dev/null; then
        soviez_json_merge_file "$dir/state.json" '{"current_state":"failed_retryable","checkpoint":"conflict"}' 2>/dev/null || true
        continue
      fi
    fi
    if soviez_image_cleanup_execute "$prod" 1 "" 0 > "$dir/result.json" 2>"$dir/error.log"; then
      soviez_json_merge_file "$dir/state.json" '{"current_state":"completed","checkpoint":"deleted"}' 2>/dev/null || true
    else
      soviez_json_merge_file "$dir/state.json" '{"current_state":"failed_retryable","checkpoint":"IMAGE_CLEANUP_NEEDS_ACTION"}' 2>/dev/null || true
    fi
  done
}
