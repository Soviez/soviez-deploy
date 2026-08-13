# shellcheck shell=bash

soviez_ops_scheduler_lock_acquire() { soviez_ops_lock_acquire "soviez-scheduler" "$(soviez_ops_lock_id host scheduler)"; }
soviez_ops_scheduler_lock_release() { soviez_ops_lock_release "soviez-scheduler" "$(soviez_ops_lock_id host scheduler)"; }

soviez_ops_scheduler_reconcile_pending() {
  local f op_id
  for f in "$SOVIEZ_OPS_INDEX_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    op_id="$(soviez_json_get "$(cat "$f")" operation_id 2>/dev/null || true)"
    [[ -n "$op_id" ]] || continue
    if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
      soviez_ops_sync_reconcile "$op_id" >/dev/null 2>&1 || true
    fi
  done
  # Also scan sync_pending markers under operations/
  local marker
  for marker in "$SOVIEZ_OPS_ROOT/operations"/*/sync_pending.json; do
    [[ -f "$marker" ]] || continue
    op_id="$(basename "$(dirname "$marker")")"
    soviez_ops_sync_reconcile "$op_id" >/dev/null 2>&1 || true
  done
}

soviez_ops_scheduler_coordinate() {
  # Priority: recovery/sync repair, then SSL monitoring, then retention.
  soviez_ops_scheduler_lock_acquire
  soviez_ops_scheduler_reconcile_pending
  if declare -F soviez_ssl_monitor_apply >/dev/null 2>&1 && declare -F soviez_ssl_inventory_list_ids >/dev/null 2>&1; then
    local eid
    while IFS= read -r eid; do
      [[ -n "$eid" ]] || continue
      # Skip if an active/pending SSL op already owns this environment
      local skip=0 rec
      for rec in $(soviez_ops_registry_list --type ssl_renewal 2>/dev/null || true); do
        :
      done
      while IFS= read -r rec; do
        [[ -n "$rec" ]] || continue
        [[ "$(soviez_json_get "$rec" environment_id)" == "$eid" ]] || continue
        case "$(soviez_json_get "$rec" current_state)" in
          completed|canceled|failed_terminal) continue ;;
          *)
            if soviez_ops_sync_is_pending "$(soviez_json_get "$rec" operation_id)" 2>/dev/null; then
              soviez_ops_sync_reconcile "$(soviez_json_get "$rec" operation_id)" >/dev/null 2>&1 || true
              skip=1
            else
              skip=1
            fi
            ;;
        esac
      done < <(soviez_ops_registry_list --type ssl_renewal 2>/dev/null || true)
      [[ "$skip" == "1" ]] && continue
      ( soviez_ssl_monitor_apply "$eid" >/dev/null ) || true
    done < <(soviez_ssl_inventory_list_ids 2>/dev/null || true)
  fi
  if declare -F soviez_retention_scheduler_scan >/dev/null 2>&1; then
    ( soviez_retention_scheduler_scan ) || true
  fi
  if declare -F soviez_backup_schedule_tick >/dev/null 2>&1; then
    ( soviez_backup_schedule_tick ) || true
  fi
  if declare -F soviez_backup_retention_cleanup >/dev/null 2>&1 && [[ "${SOVIEZ_BACKUP_AUTO_RETENTION:-0}" == "1" ]]; then
    ( soviez_backup_retention_cleanup 1 "" 0 ) || true
  fi
  soviez_ops_scheduler_lock_release
}
