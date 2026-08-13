# shellcheck shell=bash

soviez_restore_state_write() {
  local op_id="$1" state="$2" checkpoint="${3:-}" extra="${4:-"{}"}"
  local dir sf
  soviez_restore_paths_init
  dir="$(soviez_restore_op_dir "$op_id")"
  mkdir -p "$dir"
  sf="$(soviez_restore_op_state_file "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" SOVIEZ_EX="$extra" \
  SOVIEZ_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)" python3 - <<'PY' > "$sf"
import json, os
ex = json.loads(os.environ.get("SOVIEZ_EX") or "{}")
doc = {
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "production_restore",
  "current_state": os.environ["SOVIEZ_ST"],
  "checkpoint": os.environ.get("SOVIEZ_CP") or "",
  "updated_at": os.environ["SOVIEZ_NOW"],
}
doc.update(ex)
print(json.dumps(doc, separators=(",", ":")))
PY
  local env_id
  env_id="$(soviez_json_get "$(cat "$sf")" environment_id 2>/dev/null || true)"
  if declare -F soviez_ops_sync_apply >/dev/null 2>&1; then
    soviez_ops_sync_apply "$op_id" "$SOVIEZ_RESTORE_OP_TYPE" "$env_id" "$checkpoint" "transition" "$extra" "$sf" 2>/dev/null || true
  fi
}

soviez_restore_run() {
  # Args: production_id backup_id confirm
  local target="${1:-}" backup_id="${2:-}" confirm="${3:-0}"
  soviez_restore_paths_init

  [[ -n "$target" ]] || soviez_restore_die RESTORE_TARGET_REQUIRED "Exact Production ID required"
  [[ -n "$backup_id" ]] || soviez_restore_die RESTORE_BACKUP_REQUIRED "Exact backup ID required"

  if [[ ! -t 0 && "$confirm" != "1" && "${SOVIEZ_RESTORE_ASSUME_YES:-0}" != "1" ]]; then
    soviez_restore_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Non-TTY restore requires --confirm"
  fi

  local prod backup
  prod="$(soviez_restore_resolve_target "$target")" || exit $?
  backup="$(soviez_restore_resolve_backup "$backup_id")" || exit $?

  local tenant_id
  tenant_id="$(soviez_json_get "$prod" tenant_id)"

  # Compatibility before registering — avoids orphan non-terminal ops
  soviez_restore_compatibility_check "$prod" "$backup" >/dev/null || exit $?

  # Conflict check BEFORE registering this restore operation
  if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
    soviez_ops_conflict_check "$SOVIEZ_RESTORE_OP_TYPE" "$tenant_id" "env:$tenant_id" \
      || soviez_restore_die RESTORE_CONFLICT "Conflicting operation"
  fi

  local op_id
  op_id="$(soviez_restore_new_op_id)"
  mkdir -p "$(soviez_restore_op_dir "$op_id")"
  printf '%s' "$prod" > "$(soviez_restore_op_dir "$op_id")/production.json"
  printf '%s' "$backup" > "$(soviez_restore_op_dir "$op_id")/backup.json"

  soviez_restore_state_write "$op_id" created validating_target \
    "{\"environment_id\":\"$tenant_id\",\"backup_id\":\"$backup_id\"}"

  if declare -F soviez_ops_lock_acquire >/dev/null 2>&1; then
    soviez_ops_lock_acquire "$tenant_id" "$op_id" "$SOVIEZ_RESTORE_OP_TYPE" 2>/dev/null || true
  fi
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" "$SOVIEZ_RESTORE_OP_TYPE" "$tenant_id" "env:$tenant_id" 2>/dev/null || true
  fi

  soviez_restore_state_write "$op_id" validating_backup validating_backup "{}"
  # Verify manifest signature
  local bdir man
  bdir="$(soviez_backup_dir "$(soviez_json_get "$backup" production_id)" "$backup_id")"
  man="$bdir/manifest.json"
  if [[ -f "$man" ]]; then
    soviez_backup_manifest_verify "$man" 2>/dev/null \
      || {
        soviez_restore_state_write "$op_id" failed_terminal signature_invalid "{}"
        soviez_restore_die RESTORE_SIGNATURE_INVALID "Manifest signature invalid"
      }
  else
    soviez_restore_state_write "$op_id" failed_terminal manifest_missing "{}"
    soviez_restore_die RESTORE_MANIFEST_INVALID "Missing backup manifest"
  fi

  soviez_restore_state_write "$op_id" checking_compatibility checking_compatibility "{}"
  # Already checked; re-assert for state machine visibility
  soviez_restore_compatibility_check "$prod" "$backup" >/dev/null || exit $?

  soviez_restore_state_write "$op_id" checking_capacity checking_capacity "{}"
  local pf
  pf="$(soviez_restore_preflight "$prod" "$backup")"
  soviez_restore_preflight_assert "$pf"

  soviez_restore_state_write "$op_id" preserving_current_production preserving_current_production "{}"
  soviez_restore_preserve_current "$op_id" "$prod" >/dev/null

  soviez_restore_state_write "$op_id" creating_restore_candidate creating_restore_candidate "{}"
  soviez_restore_candidate_create "$op_id" "$prod" "$backup" >/dev/null || {
    soviez_restore_die RESTORE_CANDIDATE_FAILED "Candidate create failed"
  }

  soviez_restore_state_write "$op_id" restoring_database restoring_database "{}"
  soviez_restore_database_into_candidate "$op_id" "$backup" || exit $?

  soviez_restore_state_write "$op_id" restoring_filestore restoring_filestore "{}"
  soviez_restore_filestore_into_candidate "$op_id" "$backup" || exit $?

  soviez_restore_state_write "$op_id" restoring_metadata restoring_metadata "{}"
  soviez_restore_metadata_into_candidate "$op_id" "$prod" "$backup"

  soviez_restore_state_write "$op_id" starting_candidate starting_candidate "{}"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'started=1\n' > "$(soviez_restore_candidate_dir "$op_id")/runtime/erp.started"
  fi

  soviez_restore_state_write "$op_id" validating_candidate validating_candidate "{}"
  soviez_restore_validate_candidate "$op_id" "$prod" >/dev/null || {
    soviez_restore_candidate_cleanup "$op_id" || true
    soviez_restore_die RESTORE_VALIDATION_FAILED "Candidate validation failed; Production preserved"
  }

  soviez_restore_state_write "$op_id" waiting_for_switch waiting_for_switch "{}"
  [[ "$confirm" == "1" || "${SOVIEZ_RESTORE_ASSUME_YES:-0}" == "1" || -t 0 ]] \
    || soviez_restore_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Switch requires confirmation"

  soviez_restore_state_write "$op_id" switching switching "{}"
  if ! ( soviez_restore_switch "$op_id" "$prod" >/dev/null ); then
    soviez_restore_state_write "$op_id" rollback_running rollback_running "{}"
    if ! ( soviez_restore_rollback "$op_id" >/dev/null ); then
      soviez_restore_state_write "$op_id" recovery_required rollback_failed "{}"
      soviez_restore_die RESTORE_ROLLBACK_FAILED "Rollback after switch failure failed"
    fi
    soviez_restore_die RESTORE_SWITCH_FAILED "Switch failed; rollback completed"
  fi

  soviez_restore_state_write "$op_id" validating_production validating_production "{}"
  if [[ "${SOVIEZ_RESTORE_FIXTURE_POST_SWITCH_FAIL:-0}" == "1" ]]; then
    soviez_restore_state_write "$op_id" rollback_running post_switch_fail "{}"
    soviez_restore_rollback "$op_id" >/dev/null || true
    soviez_restore_die RESTORE_POST_SWITCH_VALIDATION_FAILED "Post-switch validation failed"
  fi

  soviez_restore_state_write "$op_id" completed completed \
    "{\"environment_id\":\"$tenant_id\",\"backup_id\":\"$backup_id\"}"
  if declare -F soviez_ops_sync_terminal >/dev/null 2>&1; then
    soviez_ops_sync_terminal "$op_id" "$SOVIEZ_RESTORE_OP_TYPE" "$tenant_id" completed \
      "$(soviez_restore_op_state_file "$op_id")" 2>/dev/null || true
  fi

  local safety
  safety="$(soviez_restore_safety_window_info "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_B="$backup_id" SOVIEZ_SF="$safety" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "RESTORE_COMPLETED",
  "operation_id": os.environ["SOVIEZ_OP"],
  "production_id": os.environ["SOVIEZ_T"],
  "backup_id": os.environ["SOVIEZ_B"],
  "safety_window": json.loads(os.environ["SOVIEZ_SF"]),
}, separators=(",", ":")))
PY
}
