# shellcheck shell=bash

soviez_restore_resolve_target() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    soviez_restore_die RESTORE_TARGET_REQUIRED "Exact Production environment ID required"
  fi
  if declare -F soviez_backup_refuse_wildcard >/dev/null 2>&1; then
    if soviez_backup_refuse_wildcard "$target"; then
      soviez_restore_die RESTORE_TARGET_INVALID "Wildcard/all targeting refused"
    fi
  fi
  if declare -F soviez_backup_is_stage_id >/dev/null 2>&1; then
    if soviez_backup_is_stage_id "$target"; then
      soviez_restore_die RESTORE_TARGET_INVALID "Stage targets require restore-as-stage"
    fi
  fi
  if declare -F soviez_backup_resolve_production >/dev/null 2>&1; then
    local prod
    prod="$(soviez_backup_resolve_production "$target")" || exit $?
    printf '%s' "$prod"
    return 0
  fi
  soviez_restore_die RESTORE_TARGET_INVALID "Cannot resolve Production: $target"
}

soviez_restore_resolve_backup() {
  local backup_id="${1:-}"
  [[ -n "$backup_id" ]] || soviez_restore_die RESTORE_BACKUP_REQUIRED "Exact backup ID required"
  if declare -F soviez_backup_refuse_wildcard >/dev/null 2>&1; then
    if soviez_backup_refuse_wildcard "$backup_id"; then
      soviez_restore_die RESTORE_BACKUP_NOT_FOUND "Invalid backup id"
    fi
  fi
  local obj
  obj="$(soviez_backup_read_object "$backup_id")" || soviez_restore_die RESTORE_BACKUP_NOT_FOUND "Unknown backup: $backup_id"
  printf '%s' "$obj"
}
