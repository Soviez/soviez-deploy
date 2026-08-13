# shellcheck shell=bash

soviez_restore_recovery_mark() {
  local op_id="$1" reason="${2:-ambiguous_state}"
  soviez_restore_paths_init
  local sf
  sf="$(soviez_restore_op_state_file "$op_id")"
  mkdir -p "$(soviez_restore_op_dir "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_R="$reason" SOVIEZ_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)" python3 - <<'PY' > "$sf"
import json, os
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "production_restore",
  "current_state": "recovery_required",
  "checkpoint": "recovery_required",
  "reason": os.environ["SOVIEZ_R"],
  "updated_at": os.environ["SOVIEZ_NOW"],
}, separators=(",", ":")))
PY
  soviez_restore_die RESTORE_RECOVERY_REQUIRED "Manual recovery required: $reason"
}

soviez_restore_recover() {
  local op_id="$1"
  local sf state
  sf="$(soviez_restore_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_restore_die RESTORE_RECOVERY_REQUIRED "Missing restore state"
  if declare -F soviez_ops_sync_is_pending >/dev/null 2>&1; then
    if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
      soviez_ops_sync_reconcile "$op_id" 2>/dev/null || true
    fi
  fi
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  case "$state" in
    switching|rollback_running)
      soviez_restore_recovery_mark "$op_id" "ambiguous_$state"
      ;;
    *)
      soviez_restore_ok RESTORE_RECOVERED "Recovered view of $op_id ($state)"
      ;;
  esac
}
