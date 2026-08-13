# shellcheck shell=bash
# Phase 14 corrective closure — continuous canonical synchronization.
# Write order: legacy (already written by caller) → canonical → registry → event → terminal cleanup.

soviez_ops_map_legacy_checkpoint() {
  local s="$1"
  case "$s" in
    created|queued|starting|running|waiting|retry_scheduled|cancel_requested|canceling|rollback_running|recovery_required|completed|canceled|failed_retryable|failed_terminal)
      printf '%s\n' "$s"
      ;;
    waiting_for_*|manual_activation_pending|device_authorization_pending|waiting_for_dns*|ssl.waiting*|retention.waiting*|renewal_scheduled)
      printf 'waiting\n'
      ;;
    failed|needs_action|deletion_blocked)
      printf 'failed_retryable\n'
      ;;
    deleted|tombstoned|certified|origin_certificate_issued)
      printf 'completed\n'
      ;;
    *)
      printf 'running\n'
      ;;
  esac
}

soviez_ops_sync_fail_inject() {
  local point="$1"
  [[ "${SOVIEZ_OPS_SYNC_FAIL_AT:-}" == "$point" ]] || return 0
  return 1
}

soviez_ops_sync_mark_pending() {
  local op_id="$1" code="${2:-OPERATION_CANONICAL_SYNC_PENDING}" dir marker
  dir="$(soviez_operation_dir "$op_id")"
  mkdir -p "$dir"
  marker="$dir/sync_pending.json"
  SOVIEZ_CODE="$code" SOVIEZ_NOW="$(soviez_ops_now_utc)" python3 - <<'PY' > "$marker"
import json, os
print(json.dumps({"canonical_sync_status":"pending","canonical_sync_error_code":os.environ["SOVIEZ_CODE"],
 "canonical_synced_at":None,"at":os.environ["SOVIEZ_NOW"]},separators=(",",":")))
PY
  chmod 600 "$marker" 2>/dev/null || true
}

soviez_ops_sync_clear_pending() {
  rm -f "$(soviez_operation_dir "$1")/sync_pending.json" 2>/dev/null || true
}

soviez_ops_sync_is_pending() {
  local op_id="$1" path status
  path="$(soviez_ops_canonical_state_path "$op_id")"
  [[ -f "$(soviez_operation_dir "$op_id")/sync_pending.json" ]] && return 0
  [[ -f "$path" ]] || return 1
  status="$(soviez_json_get "$(cat "$path")" canonical_sync_status 2>/dev/null || true)"
  [[ "$status" == "pending" || "$status" == "incomplete" || "$status" == "failed" ]]
}

soviez_ops_sync_apply() {
  # Args: op_id op_type env_id legacy_checkpoint [event_type] [extra_json] [legacy_state_file]
  local op_id="$1" op_type="$2" env_id="${3:-}" legacy_cp="$4" event_type="${5:-transition}" extra="${6:-{}}" legacy_file="${7:-}"
  local shared path existing rev now updated seq last_sync terminal_cleanup=0

  soviez_ops_paths_init 2>/dev/null || true
  shared="$(soviez_ops_map_legacy_checkpoint "$legacy_cp")"
  path="$(soviez_ops_canonical_state_path "$op_id")"
  mkdir -p "$(dirname "$path")"
  now="$(soviez_ops_now_utc)"

  if [[ ! -f "$path" ]]; then
    existing="$(soviez_ops_new_record "$op_id" "$op_type" "$env_id" "$legacy_cp")"
  else
    existing="$(cat "$path")"
  fi

  # Idempotent: same logical transition already synchronized
  last_sync="$(soviez_json_get "$existing" last_synchronized_transition 2>/dev/null || true)"
  if [[ "$last_sync" == "${legacy_cp}|${shared}" && "$(soviez_json_get "$existing" canonical_sync_status 2>/dev/null || true)" == "synchronized" ]]; then
    soviez_ops_sync_clear_pending "$op_id"
    return 0
  fi

  if ! soviez_ops_sync_fail_inject before_canonical; then
    soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
    return 22
  fi

  updated="$(SOVIEZ_CUR="$existing" SOVIEZ_SHARED="$shared" SOVIEZ_CP="$legacy_cp" \
    SOVIEZ_ENV="$env_id" SOVIEZ_TYPE="$op_type" SOVIEZ_NOW="$now" SOVIEZ_EXTRA="$extra" \
    SOVIEZ_LEGACY="$legacy_file" python3 - <<'PY'
import json, os, time
d=json.loads(os.environ["SOVIEZ_CUR"])
shared=os.environ["SOVIEZ_SHARED"]; cp=os.environ["SOVIEZ_CP"]; now=os.environ["SOVIEZ_NOW"]
prev=d.get("current_state")
# Prevent silent backward shared-state regression unless recovery/cancel/fail paths
terminal={"completed","canceled","failed_terminal"}
if prev in terminal and shared not in terminal and shared != "recovery_required":
    raise SystemExit(7)
d["previous_state"]=prev
d["current_state"]=shared
d["current_checkpoint"]=cp
d["operation_type"]=os.environ["SOVIEZ_TYPE"] or d.get("operation_type")
if os.environ.get("SOVIEZ_ENV"):
    d["environment_id"]=os.environ["SOVIEZ_ENV"]
d["updated_at"]=now
d["state_entered_at"]=now
rev=int(d.get("canonical_state_revision") or d.get("sequence") or 0)+1
d["canonical_state_revision"]=rev
d["legacy_state_revision"]=rev
d["canonical_sync_revision"]=rev
d["registry_revision"]=rev
d["sequence"]=rev
d["event_sequence"]=rev
d["canonical_sync_status"]="synchronized"
d["canonical_synced_at"]=now
d["canonical_sync_error_code"]=None
d["last_synchronized_transition"]=f"{cp}|{shared}"
d["terminal"]=shared in ("completed","canceled","failed_terminal")
if shared=="completed":
    d["success"]=True; d["completed_at"]=now; d["terminal_cleanup_status"]="pending"
elif shared in ("canceled","failed_terminal"):
    d["success"]=False; d["completed_at"]=now; d["terminal_cleanup_status"]="pending"
    if shared=="failed_terminal": d["failed_at"]=now
elif shared=="failed_retryable":
    d["success"]=False; d["failed_at"]=now
elif shared=="recovery_required":
    d["recovery_required"]=True
try:
    extra=json.loads(os.environ.get("SOVIEZ_EXTRA") or "{}")
    if isinstance(extra, dict) and extra:
        meta=d.get("meta") if isinstance(d.get("meta"), dict) else {}
        meta.update(extra); d["meta"]=meta
except Exception:
    pass
if os.environ.get("SOVIEZ_LEGACY"):
    meta=d.get("meta") if isinstance(d.get("meta"), dict) else {}
    meta["legacy_state_path"]=os.environ["SOVIEZ_LEGACY"]; d["meta"]=meta
print(json.dumps(d,separators=(",",":")))
PY
)" || {
    soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_REVISION_MISMATCH
    return 22
  }

  soviez_ops_validate_record "$updated" || {
    soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
    return 22
  }

  if ! soviez_stage_inventory_atomic_write "$path" "$updated"; then
    soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
    return 22
  fi

  if ! soviez_ops_sync_fail_inject before_registry; then
    soviez_ops_sync_mark_pending "$op_id" OPERATION_REGISTRY_SYNC_FAILED
    # Mark canonical as incomplete for registry
    updated="$(SOVIEZ_CUR="$updated" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["canonical_sync_status"]="incomplete"; d["canonical_sync_error_code"]="OPERATION_REGISTRY_SYNC_FAILED"
print(json.dumps(d,separators=(",",":")))
PY
)"
    soviez_stage_inventory_atomic_write "$path" "$updated" 2>/dev/null || true
    return 22
  fi

  if ! soviez_ops_registry_register "$op_id"; then
    soviez_ops_sync_mark_pending "$op_id" OPERATION_REGISTRY_SYNC_FAILED
    return 22
  fi

  if ! soviez_ops_sync_fail_inject before_event; then
    soviez_ops_sync_mark_pending "$op_id" OPERATION_EVENT_SYNC_FAILED
    return 22
  fi

  # Duplicate event prevention: skip if events already contain this sequence/revision
  seq="$(soviez_json_get "$updated" sequence)"
  events="$(soviez_ops_events_path "$op_id")"
  mkdir -p "$(dirname "$events")"; chmod 700 "$(dirname "$events")" 2>/dev/null || true
  if [[ -f "$events" ]] && grep -Fq "\"sequence\":${seq}," "$events" 2>/dev/null; then
    :
  else
    if ! SOVIEZ_EVT_TYPE="$event_type" SOVIEZ_EVT_MSG="$(soviez_redact_text "$legacy_cp -> $shared")" \
      SOVIEZ_EVT_SEQ="$seq" SOVIEZ_EVT_CP="$legacy_cp" python3 - <<'PY' >> "$events"
import json, os, time
print(json.dumps({"sequence":int(os.environ["SOVIEZ_EVT_SEQ"]),"at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
 "event_type":os.environ["SOVIEZ_EVT_TYPE"],"message":os.environ["SOVIEZ_EVT_MSG"],
 "checkpoint":os.environ["SOVIEZ_EVT_CP"],"redaction":"applied"},separators=(",",":")))
PY
    then
      soviez_ops_sync_mark_pending "$op_id" OPERATION_EVENT_SYNC_FAILED
      return 22
    fi
    chmod 600 "$events" 2>/dev/null || true
  fi

  case "$shared" in
    completed|canceled|failed_terminal)
      if ! soviez_ops_sync_fail_inject before_history; then
        soviez_ops_sync_mark_pending "$op_id" OPERATION_TERMINAL_SYNC_INCOMPLETE
        return 22
      fi
      soviez_ops_history_append "$op_id" 2>/dev/null || {
        soviez_ops_sync_mark_pending "$op_id" OPERATION_TERMINAL_SYNC_INCOMPLETE
        return 22
      }
      if ! soviez_ops_sync_fail_inject before_lock_cleanup; then
        soviez_ops_sync_mark_pending "$op_id" OPERATION_TERMINAL_SYNC_INCOMPLETE
        return 22
      fi
      # Idempotent terminal cleanup marker; resource locks released by command engines.
      updated="$(SOVIEZ_CUR="$(cat "$path")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["terminal_cleanup_status"]="done"
print(json.dumps(d,separators=(",",":")))
PY
)"
      soviez_stage_inventory_atomic_write "$path" "$updated"
      soviez_ops_registry_register "$op_id" 2>/dev/null || true
      ;;
  esac

  soviez_ops_sync_clear_pending "$op_id"
  return 0
}

soviez_ops_sync_create() {
  local op_id="$1" op_type="$2" env_id="${3:-}" legacy_file="${4:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "created" "created" "{}" "$legacy_file"
}

soviez_ops_sync_transition() {
  soviez_ops_sync_apply "$@"
}

soviez_ops_sync_checkpoint() {
  local op_id="$1" op_type="$2" env_id="$3" checkpoint="$4" legacy_file="${5:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$checkpoint" "checkpoint" "{}" "$legacy_file"
}

soviez_ops_sync_heartbeat() {
  local op_id="$1"
  if declare -F soviez_ops_heartbeat_touch >/dev/null 2>&1; then
    soviez_ops_heartbeat_touch "$op_id" 2>/dev/null || true
  fi
  local path; path="$(soviez_ops_canonical_state_path "$op_id")"
  [[ -f "$path" ]] || return 0
  local updated
  updated="$(SOVIEZ_CUR="$(cat "$path")" SOVIEZ_NOW="$(soviez_ops_now_utc)" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["heartbeat_at"]=os.environ["SOVIEZ_NOW"]; d["updated_at"]=os.environ["SOVIEZ_NOW"]
print(json.dumps(d,separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$path" "$updated"
  soviez_ops_registry_register "$op_id" 2>/dev/null || true
}

soviez_ops_sync_retry() {
  local op_id="$1" op_type="$2" env_id="$3" legacy_file="${4:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "retry_scheduled" "retry" "{}" "$legacy_file"
}

soviez_ops_sync_cancel() {
  local op_id="$1" op_type="$2" env_id="$3" checkpoint="${4:-cancel_requested}" legacy_file="${5:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$checkpoint" "cancel" "{}" "$legacy_file"
}

soviez_ops_sync_rollback() {
  local op_id="$1" op_type="$2" env_id="$3" checkpoint="${4:-rollback_running}" legacy_file="${5:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$checkpoint" "rollback" "{}" "$legacy_file"
}

soviez_ops_sync_recovery() {
  local op_id="$1" op_type="$2" env_id="$3" checkpoint="${4:-recovery_required}" legacy_file="${5:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$checkpoint" "recovery" "{}" "$legacy_file"
}

soviez_ops_sync_terminal() {
  local op_id="$1" op_type="$2" env_id="$3" outcome="${4:-completed}" legacy_file="${5:-}"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$outcome" "terminal" "{}" "$legacy_file"
}

soviez_ops_sync_from_legacy_file() {
  local op_id="$1" op_type="$2" legacy_file="$3" env_id="${4:-}" state
  [[ -f "$legacy_file" ]] || return 1
  state="$(soviez_json_get "$(cat "$legacy_file")" state 2>/dev/null || true)"
  [[ -n "$state" ]] || state="$(soviez_json_get "$(cat "$legacy_file")" ssl_state 2>/dev/null || true)"
  [[ -n "$state" ]] || state="$(soviez_json_get "$(cat "$legacy_file")" retention_status 2>/dev/null || true)"
  [[ -n "$env_id" ]] || env_id="$(soviez_json_get "$(cat "$legacy_file")" environment_id 2>/dev/null || true)"
  [[ -n "$env_id" ]] || env_id="$(soviez_json_get "$(cat "$legacy_file")" stage_id 2>/dev/null || true)"
  [[ -n "$state" ]] || state="running"
  soviez_ops_sync_apply "$op_id" "$op_type" "$env_id" "$state" "sync" "{}" "$legacy_file"
}

soviez_ops_sync_reconcile() {
  local op_id="$1" path legacy decision="OPERATION_SYNC_RECONCILED"
  path="$(soviez_ops_canonical_state_path "$op_id")"
  # Prefer legacy state file pointers
  local candidates=()
  candidates+=("$(soviez_operation_state_file "$op_id")")
  [[ -n "${SOVIEZ_STAGE_OPS_DIR:-}" ]] && candidates+=("$SOVIEZ_STAGE_OPS_DIR/$op_id/state.json")
  [[ -n "${SOVIEZ_SSL_OPS_DIR:-}" ]] && candidates+=("$SOVIEZ_SSL_OPS_DIR/$op_id/state.json")
  local f type="new" env=""
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] || continue
    legacy="$f"
    type="$(soviez_json_get "$(cat "$f")" kind 2>/dev/null || echo new)"
    case "$type" in stage) type=stage_create ;; ssl*) type=ssl_renewal ;; retention*) type=retention_delete ;; esac
    env="$(soviez_json_get "$(cat "$f")" environment_id 2>/dev/null || true)"
    break
  done
  if [[ -z "${legacy:-}" ]]; then
    # Retention: scan by retention_operation_id is expensive; rely on meta path
    if [[ -f "$path" ]]; then
      local meta_path
      meta_path="$(SOVIEZ_CUR="$(cat "$path")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); print((d.get("meta") or {}).get("legacy_state_path") or "")
PY
)"
      [[ -f "$meta_path" ]] && legacy="$meta_path"
      type="$(soviez_json_get "$(cat "$path")" operation_type)"
      env="$(soviez_json_get "$(cat "$path")" environment_id)"
    fi
  fi
  if [[ -n "${legacy:-}" && -f "$legacy" ]]; then
    if soviez_ops_sync_from_legacy_file "$op_id" "$type" "$legacy" "$env"; then
      soviez_ops_append_event "$op_id" "reconcile" "canonical repaired from legacy" "{}" 2>/dev/null || true
      printf '%s\n' "$decision"
      return 0
    fi
    printf 'OPERATION_SYNC_RECOVERY_REQUIRED\n'
    return 1
  fi
  if [[ -f "$path" ]]; then
    soviez_ops_registry_register "$op_id" 2>/dev/null || true
    printf '%s\n' "$decision"
    return 0
  fi
  printf 'OPERATION_SYNC_RECOVERY_REQUIRED\n'
  return 1
}
