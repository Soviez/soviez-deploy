# shellcheck shell=bash
# Phase 16 backup/restore reboot reconciliation — no blind destructive replay.

soviez_backup_reboot_reconcile() {
  local op_id="$1"
  soviez_backup_paths_init
  local sf state checkpoint
  sf="$(soviez_backup_op_state_file "$op_id")"
  if [[ ! -f "$sf" ]]; then
    soviez_backup_die BACKUP_RECOVERY_REQUIRED "Missing backup op state after reboot"
  fi
  if declare -F soviez_ops_sync_is_pending >/dev/null 2>&1; then
    if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
      soviez_ops_sync_reconcile "$op_id" 2>/dev/null || true
    fi
  fi
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  checkpoint="$(soviez_json_get "$(cat "$sf")" checkpoint 2>/dev/null || true)"
  local backup_id prod_id
  backup_id="$(soviez_json_get "$(cat "$sf")" backup_id 2>/dev/null || true)"
  prod_id="$(soviez_json_get "$(cat "$sf")" environment_id 2>/dev/null || true)"

  case "$state:$checkpoint" in
    recovery_required:*|*:recovery_required)
      ;;
    *uploading*|*multipart*|*completing_upload*|*remote_delete*|*retention_delet*|*encrypting*|*switching*|*rollback*)
      soviez_backup_state_write "$op_id" recovery_required "$checkpoint" \
        "{\"reboot\":true,\"ambiguous\":true}"
      state=recovery_required
      ;;
  esac

  # Destructive remote finalization / deletion / switch-like checkpoints → recovery_required
  case "$checkpoint" in
    s3_multipart_upload|s3_upload_complete|s3_exact_deletion|sftp_upload|sftp_atomic_rename|sftp_exact_deletion|\
    local_backup_delete|retention_delete|cleanup_history|production_switch|production_rollback|\
    encrypting|archive_verify|application_resume)
      if [[ "$state" != "completed" && "$state" != "canceled" && "$state" != "failed_terminal" ]]; then
        case "$state" in
          recovery_required) ;;
          *)
            soviez_backup_state_write "$op_id" recovery_required "$checkpoint" "{\"reboot\":true}"
            state=recovery_required
            ;;
        esac
      fi
      ;;
  esac

  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" \
  SOVIEZ_B="$backup_id" SOVIEZ_P="$prod_id" python3 - <<'PY'
import json, os
st = os.environ.get("SOVIEZ_ST") or ""
code = "BACKUP_RECOVERY_REQUIRED" if st == "recovery_required" else "BACKUP_REBOOT_RECONCILED"
print(json.dumps({
  "ok": st != "recovery_required",
  "code": code,
  "operation_id": os.environ["SOVIEZ_OP"],
  "current_state": st,
  "checkpoint": os.environ.get("SOVIEZ_CP"),
  "backup_id": os.environ.get("SOVIEZ_B"),
  "production_id": os.environ.get("SOVIEZ_P"),
  "duplicate_backup": False,
  "duplicate_multipart_complete": False,
  "duplicate_sftp_final": False,
  "duplicate_delete": False,
  "destructive_replay": False,
  "locks_stolen": False,
}, separators=(",", ":")))
PY
}

soviez_restore_reboot_reconcile() {
  local op_id="$1"
  soviez_restore_paths_init
  local sf state checkpoint
  sf="$(soviez_restore_op_state_file "$op_id")"
  if [[ ! -f "$sf" ]]; then
    soviez_restore_die RESTORE_RECOVERY_REQUIRED "Missing restore op state after reboot"
  fi
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  checkpoint="$(soviez_json_get "$(cat "$sf")" checkpoint 2>/dev/null || true)"

  case "$state:$checkpoint" in
    switching:*|*:switching|rollback_running:*|*:rollback*|recovery_required:*|*:recovery_required)
      soviez_restore_state_write "$op_id" recovery_required "$checkpoint" "{\"reboot\":true}"
      SOVIEZ_OP="$op_id" SOVIEZ_CP="$checkpoint" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": False,
  "code": "RESTORE_RECOVERY_REQUIRED",
  "operation_id": os.environ["SOVIEZ_OP"],
  "checkpoint": os.environ.get("SOVIEZ_CP"),
  "duplicate_switch": False,
  "duplicate_rollback": False,
  "destructive_replay": False,
  "plan": "manual_recovery_required_no_blind_replay",
}, separators=(",", ":")))
PY
      return 0
      ;;
    completed:*)
      printf '{"ok":true,"code":"RESTORE_REBOOT_RECONCILED","state":"completed","destructive_replay":false}\n'
      return 0
      ;;
  esac

  case "$checkpoint" in
    candidate_db_restore|candidate_filestore_restore|candidate_startup|candidate_validation|candidate_cleanup|\
    preserving_current|pre_switch|post_switch|safety_window_schedule)
      if [[ "$state" != "completed" ]]; then
        soviez_restore_state_write "$op_id" recovery_required "$checkpoint" "{\"reboot\":true}"
        printf '{"ok":false,"code":"RESTORE_RECOVERY_REQUIRED","checkpoint":"%s","destructive_replay":false}\n' "$checkpoint"
        return 0
      fi
      ;;
  esac

  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "RESTORE_REBOOT_RECONCILED",
  "operation_id": os.environ["SOVIEZ_OP"],
  "current_state": os.environ.get("SOVIEZ_ST"),
  "checkpoint": os.environ.get("SOVIEZ_CP"),
  "duplicate_switch": False,
  "duplicate_rollback": False,
  "destructive_replay": False,
}, separators=(",", ":")))
PY
}
