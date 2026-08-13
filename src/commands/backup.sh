# shellcheck shell=bash

soviez_cmd_backup_run() {
  local target="${SOVIEZ_CLI_BACKUP_TARGET:-${SOVIEZ_CLI_TARGET:-}}"
  local dest="${SOVIEZ_CLI_BACKUP_DESTINATION:-local-primary}"
  local btype="${SOVIEZ_CLI_BACKUP_TYPE:-full}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ "${SOVIEZ_CLI_ADVANCED:-0}" == "1" ]] && export SOVIEZ_BACKUP_ADVANCED_ACK=1
  soviez_backup_run "$target" "$dest" "$btype" "$confirm"
}

soviez_cmd_backup_status() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-}}"
  [[ -n "$op_id" ]] || soviez_backup_die BACKUP_TARGET_REQUIRED "operation-id required"
  soviez_backup_paths_init
  local sf
  sf="$(soviez_backup_op_state_file "$op_id")"
  [[ -f "$sf" ]] || soviez_backup_die BACKUP_NOT_FOUND "Unknown backup operation: $op_id"
  cat "$sf"
}

soviez_cmd_backup_list() {
  local prod="${SOVIEZ_CLI_BACKUP_PRODUCTION:-${SOVIEZ_CLI_TARGET:-}}"
  soviez_backup_inventory_list "$prod"
}

soviez_cmd_backup_show() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup-id required"
  soviez_backup_inventory_show "$backup_id"
}

soviez_cmd_backup_verify() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup-id required"
  soviez_backup_verify_level1 "$backup_id"
}

soviez_cmd_backup_restore_test() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup-id required"
  soviez_backup_restore_test "$backup_id"
}

soviez_cmd_backup_export() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  local out="${SOVIEZ_CLI_BACKUP_OUTPUT:-}"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup-id required"
  soviez_backup_export "$backup_id" "$out"
}

soviez_cmd_backup_import() {
  local path="${1:-${SOVIEZ_CLI_BACKUP_IMPORT_PATH:-}}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_backup_import "$path" "$confirm"
}

soviez_cmd_backup_pin() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  soviez_backup_inventory_pin "$backup_id"
}

soviez_cmd_backup_unpin() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  soviez_backup_inventory_unpin "$backup_id"
}

soviez_cmd_backup_delete() {
  local backup_id="${1:-${SOVIEZ_CLI_BACKUP_ID:-}}"
  local dry_run="${SOVIEZ_CLI_DRY_RUN:-0}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup-id required"
  local obj prod_id
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  if [[ "$(soviez_json_get "$obj" pinned)" == "true" || "$(soviez_json_get "$obj" pinned)" == "True" ]]; then
    soviez_backup_die BACKUP_PIN_PROTECTED "Cannot delete pinned backup"
  fi
  if [[ "$dry_run" == "1" ]]; then
    SOVIEZ_BID="$backup_id" python3 - <<'PY'
import json, os
print(json.dumps({"ok": True, "dry_run": True, "would_delete": os.environ["SOVIEZ_BID"]}, separators=(",", ":")))
PY
    return 0
  fi
  [[ "$confirm" == "1" ]] || soviez_backup_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Delete requires --confirm"
  local bdir
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  case "$bdir" in
    "$SOVIEZ_BACKUP_DATA_DIR"/*) rm -rf "$bdir" ;;
    *) soviez_backup_die BACKUP_PATH_DENIED "Refusing delete outside data dir" ;;
  esac
  soviez_backup_inventory_remove "$backup_id"
  soviez_backup_ok BACKUP_DELETED "Deleted $backup_id"
}

soviez_cmd_backup_retention_status() {
  local prod="${SOVIEZ_CLI_BACKUP_PRODUCTION:-}"
  soviez_backup_retention_classify "$prod"
}

soviez_cmd_backup_retention_cleanup() {
  local dry_run="${SOVIEZ_CLI_DRY_RUN:-0}"
  local prod="${SOVIEZ_CLI_BACKUP_PRODUCTION:-}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ "$dry_run" == "1" ]] || dry_run=0
  # Default to dry-run unless explicitly cleaning
  if [[ "${SOVIEZ_CLI_BACKUP_RETENTION_EXECUTE:-0}" != "1" && "$confirm" != "1" ]]; then
    dry_run=1
  fi
  soviez_backup_retention_cleanup "$dry_run" "$prod" "$confirm"
}

soviez_cmd_backup_destination_list() {
  soviez_backup_destination_list
}

soviez_cmd_backup_destination_show() {
  local pid="${1:-${SOVIEZ_CLI_BACKUP_DESTINATION:-}}"
  soviez_backup_destination_show "$pid"
}

soviez_cmd_backup_destination_test() {
  local pid="${1:-${SOVIEZ_CLI_BACKUP_DESTINATION:-}}"
  soviez_backup_destination_test "$pid"
}

soviez_cmd_backup_schedule_list() {
  soviez_backup_schedule_list
}

soviez_cmd_backup_schedule_add() {
  local prod="${SOVIEZ_CLI_BACKUP_TARGET:-${SOVIEZ_CLI_TARGET:-}}"
  local dest="${SOVIEZ_CLI_BACKUP_DESTINATION:-local-primary}"
  soviez_backup_schedule_add "$prod" "$dest"
}
