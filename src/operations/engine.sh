# shellcheck shell=bash

soviez_op_generate_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    openssl rand -hex 16 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
  fi
}

soviez_op_create() {
  local op_id="${1:-${SOVIEZ_CLI_OP_ID:-$(soviez_op_generate_id)}}"
  local dir
  dir="$(soviez_operation_dir "$op_id")"
  mkdir -p "$dir"
  chmod 700 "$dir"
  local state_file
  state_file="$(soviez_operation_state_file "$op_id")"
  if [[ ! -f "$state_file" ]]; then
    cat > "$state_file" <<EOF
{
  "operation_id": "$op_id",
  "kind": "new",
  "state": "created",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    chmod 600 "$state_file"
    soviez_op_append_event "$op_id" "created" "{}"
    if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
      soviez_ops_sync_create "$op_id" new "" "$state_file" || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
    fi
  fi
  printf '%s' "$op_id"
}

soviez_op_read_state() {
  local op_id="$1"
  soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" "state"
}

soviez_op_transition() {
  local op_id="$1"
  local new_state="$2"
  local meta_json="${3:-}"
  [[ -n "$meta_json" ]] || meta_json='{}'
  local state_file
  state_file="$(soviez_operation_state_file "$op_id")"
  local current
  current="$(soviez_op_read_state "$op_id")"
  if [[ "$current" != "$new_state" ]]; then
    soviez_sm_assert_transition "$current" "$new_state"
  fi
  soviez_json_merge_file "$state_file" "$(SOVIEZ_NEW_STATE="$new_state" SOVIEZ_META="$meta_json" python3 - <<'PY'
import json, os, time
patch = {"state": os.environ["SOVIEZ_NEW_STATE"], "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
meta = json.loads(os.environ.get("SOVIEZ_META", "{}"))
if meta:
    patch["meta"] = meta
print(json.dumps(patch))
PY
)"
  soviez_op_append_event "$op_id" "$new_state" "$meta_json"
  soviez_op_heartbeat "$op_id"
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    local env_id
    env_id="$(soviez_json_get "$(cat "$state_file")" environment_id 2>/dev/null || true)"
    if ! soviez_ops_sync_transition "$op_id" new "$env_id" "$new_state" "transition" "$meta_json" "$state_file"; then
      # Non-destructive progress: mark pending; protected steps must check sync before proceeding.
      soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_PENDING
      case "$new_state" in
        tenant_identity_created|database_provisioned|container_started)
          soviez_die "$SOVIEZ_ERR_STATE" "Canonical sync failed before protected step: $new_state"
          ;;
      esac
    fi
  fi
}

soviez_op_append_event() {
  local op_id="$1"
  local event="$2"
  local payload="${3:-}"
  [[ -n "$payload" ]] || payload='{}'
  local events
  events="$(soviez_operation_events_file "$op_id")"
  local redacted
  redacted="$(soviez_redact_text "$payload")"
  SOVIEZ_EVT="$event" SOVIEZ_PAYLOAD="$redacted" python3 - <<'PY' >> "$events"
import json, os, time
print(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": os.environ["SOVIEZ_EVT"], "payload": json.loads(os.environ.get("SOVIEZ_PAYLOAD", "{}"))}, separators=(",", ":")))
PY
}

soviez_op_heartbeat() {
  local op_id="$1"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$(soviez_operation_heartbeat_file "$op_id")"
  if declare -F soviez_ops_sync_heartbeat >/dev/null 2>&1; then
    soviez_ops_sync_heartbeat "$op_id" 2>/dev/null || true
  fi
}

soviez_op_acquire_lock() {
  local op_id="$1"
  local lock
  lock="$(soviez_operation_lock_file "$op_id")"
  if ! mkdir "$lock" 2>/dev/null; then
    soviez_die "$SOVIEZ_ERR_STATE" "Operation locked: $op_id"
  fi
}

soviez_op_release_lock() {
  local op_id="$1"
  rmdir "$(soviez_operation_lock_file "$op_id")" 2>/dev/null || true
}
