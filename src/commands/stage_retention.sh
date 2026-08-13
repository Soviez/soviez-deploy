# shellcheck shell=bash
# Phase 13 — Stage retention CLI commands.

soviez_cmd_stage_retention_status() {
  soviez_retention_status "${1:-}"
}

soviez_cmd_stage_retention_extend() {
  local stage_id="$1"
  local days="$2"
  local yes_flag="${3:-}"
  soviez_retention_extend "$stage_id" "$days" "$yes_flag"
}

soviez_cmd_stage_retention_run() {
  local stage_id="$1"
  # Manual run still requires deadline due unless SOVIEZ_RETENTION_FORCE_DUE=1 (tests)
  if [[ "${SOVIEZ_RETENTION_FORCE_DUE:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_RETENTION_RUN_CONFIRM:-}" != "$stage_id" ]]; then
      if [[ -t 0 ]]; then
        printf 'Type the Stage ID to confirm retention deletion: ' >&2
        local typed
        read -r typed
        [[ "$typed" == "$stage_id" ]] || soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Confirmation mismatch"
      else
        soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Set SOVIEZ_RETENTION_RUN_CONFIRM=$stage_id"
      fi
    fi
    soviez_retention_run_deletion "$stage_id" 1
  else
    if [[ "${SOVIEZ_RETENTION_RUN_CONFIRM:-}" != "$stage_id" && ! -t 0 ]]; then
      soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Set SOVIEZ_RETENTION_RUN_CONFIRM=$stage_id for non-TTY manual run"
    fi
    if [[ "${SOVIEZ_RETENTION_RUN_CONFIRM:-}" != "$stage_id" && -t 0 ]]; then
      printf 'Type the Stage ID to confirm retention deletion: ' >&2
      local typed
      read -r typed
      [[ "$typed" == "$stage_id" ]] || soviez_retention_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Confirmation mismatch"
    fi
    soviez_retention_run_deletion "$stage_id" 0
  fi
}

soviez_cmd_stage_retention_retry() {
  soviez_retention_retry "$1"
}

soviez_cmd_stage_retention_reattach() {
  local op_id="$1"
  [[ -n "$op_id" ]] || soviez_retention_die STAGE_NOT_FOUND "operation-id required"
  soviez_stage_paths_init
  # Find stage whose retention_operation_id matches
  local sid found=""
  while IFS= read -r sid; do
    [[ -z "$sid" ]] && continue
    [[ -f "$(soviez_retention_file "$sid")" ]] || continue
    local oid
    oid="$(soviez_json_get "$(soviez_retention_read "$sid")" retention_operation_id)"
    if [[ "$oid" == "$op_id" ]]; then
      found="$sid"
      break
    fi
  done < <(soviez_stage_inventory_list_ids)
  [[ -n "$found" ]] || soviez_retention_die STAGE_NOT_FOUND "No Stage with retention_operation_id=$op_id"
  echo "Reattaching retention operation $op_id for stage $found"
  soviez_retention_retry "$found"
}

soviez_cmd_stage_retention_scan() {
  soviez_retention_scheduler_scan
}
