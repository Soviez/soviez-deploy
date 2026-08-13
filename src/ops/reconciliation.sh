# shellcheck shell=bash

soviez_ops_reconcile_one() {
  local op_id="$1" record state pid unit host
  # Prefer sync repair when pending/stale
  if declare -F soviez_ops_sync_is_pending >/dev/null 2>&1 && soviez_ops_sync_is_pending "$op_id"; then
    if declare -F soviez_ops_sync_reconcile >/dev/null 2>&1; then
      if soviez_ops_sync_reconcile "$op_id" >/dev/null; then
        printf 'OPERATION_SYNC_RECONCILED\n'
        return 0
      fi
      printf 'recovery_required\n'
      return 0
    fi
  fi

  record="$(cat "$(soviez_ops_canonical_state_path "$op_id")" 2>/dev/null || true)"
  if [[ -z "$record" ]]; then
    if declare -F soviez_ops_sync_reconcile >/dev/null 2>&1 && soviez_ops_sync_reconcile "$op_id" >/dev/null; then
      printf 'OPERATION_SYNC_RECONCILED\n'
      return 0
    fi
    if [[ -f "$(soviez_operation_state_file "$op_id" 2>/dev/null || true)" ]] || [[ -d "$(soviez_ops_resolve_dir "$op_id")" ]]; then
      soviez_ops_migrate_one "$op_id" 2>/dev/null || true
      record="$(cat "$(soviez_ops_canonical_state_path "$op_id")" 2>/dev/null || true)"
    fi
  fi
  [[ -n "$record" ]] || { printf 'recovery_required\n'; return 0; }

  # Repair registry if canonical newer
  local idx rev_c rev_i
  idx="$(soviez_ops_registry_index_path "$op_id")"
  rev_c="$(soviez_json_get "$record" canonical_state_revision 2>/dev/null || echo 0)"
  if [[ -f "$idx" ]]; then
    rev_i="$(soviez_json_get "$(cat "$idx")" registry_revision 2>/dev/null || soviez_json_get "$(cat "$idx")" sequence 2>/dev/null || echo 0)"
    if [[ "${rev_c:-0}" -gt "${rev_i:-0}" ]]; then
      soviez_ops_registry_register "$op_id" 2>/dev/null || true
    fi
  else
    soviez_ops_registry_register "$op_id" 2>/dev/null || true
  fi

  state="$(soviez_json_get "$record" current_state)"
  pid="$(soviez_json_get "$record" worker_pid 2>/dev/null || true)"
  unit="$(soviez_json_get "$record" systemd_unit 2>/dev/null || true)"
  host="$(soviez_json_get "$record" host_identity 2>/dev/null || true)"
  if [[ -n "$host" && "$host" != "unknown" ]]; then
    local here; here="$(hostname -f 2>/dev/null || hostname || echo unknown)"
    if [[ "$host" != "$here" && "$host" != "$(hostname 2>/dev/null || true)" ]]; then
      printf 'recovery_required\n'
      return 0
    fi
  fi

  case "$state" in
    completed|canceled|failed_terminal)
      printf 'cleanup_terminal_metadata\n'
      return 0
      ;;
    recovery_required)
      printf 'recovery_required\n'
      return 0
      ;;
    failed_retryable|retry_scheduled)
      printf 'retry_scheduled\n'
      return 0
      ;;
  esac

  if [[ -n "$pid" && "$pid" != "null" && "$pid" != "0" ]]; then
    if kill -0 "$pid" 2>/dev/null; then
      local cmdline
      cmdline="$(ps -p "$pid" -o args= 2>/dev/null || true)"
      if [[ -n "$cmdline" ]] && ! printf '%s' "$cmdline" | grep -Eqi 'soviez|bash|systemd'; then
        printf 'recovery_required\n'
        return 0
      fi
      printf 'healthy\n'
      return 0
    fi
    if soviez_ops_heartbeat_stale "$op_id"; then
      case "$state" in
        running|starting)
          local cp; cp="$(soviez_json_get "$record" current_checkpoint)"
          case "$cp" in
            *delete*|*drop*|*restore*|*promote*|*tenant_identity*)
              printf 'recovery_required\n'
              ;;
            *)
              printf 'resume_safe\n'
              ;;
          esac
          return 0
          ;;
      esac
    fi
    printf 'attach_existing\n'
    return 0
  fi

  if [[ -n "$unit" && "$unit" != "null" ]] && command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      printf 'attach_existing\n'
      return 0
    fi
  fi
  if soviez_ops_heartbeat_stale "$op_id"; then
    printf 'resume_safe\n'
  else
    printf 'attach_existing\n'
  fi
}

soviez_ops_reconcile_all() {
  local f
  for f in "$SOVIEZ_OPS_INDEX_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    printf '%s %s\n' "$(soviez_json_get "$(cat "$f")" operation_id)" "$(soviez_ops_reconcile_one "$(soviez_json_get "$(cat "$f")" operation_id)")"
  done
}
