# shellcheck shell=bash
# Stage operation engine helpers (durable state under SOVIEZ_STAGE_OPS_DIR).

soviez_stage_op_create() {
  local op_id="${1:-$(soviez_op_generate_id)}"
  local dir
  dir="$(soviez_stage_op_dir "$op_id")"
  mkdir -p "$dir"
  chmod 700 "$dir"
  local state_file
  state_file="$(soviez_stage_op_state_file "$op_id")"
  if [[ ! -f "$state_file" ]]; then
    cat > "$state_file" <<EOF
{
  "operation_id": "$op_id",
  "kind": "stage",
  "state": "created",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    chmod 600 "$state_file"
  fi
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" stage_create "" "$state_file" || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
  fi
  printf '%s' "$op_id"
}

soviez_stage_op_read_state() {
  soviez_json_get "$(cat "$(soviez_stage_op_state_file "$1")")" state
}

soviez_stage_op_transition() {
  local op_id="$1"
  local new_state="$2"
  local meta_json="${3:-{}}"
  local state_file current
  state_file="$(soviez_stage_op_state_file "$op_id")"
  current="$(soviez_stage_op_read_state "$op_id")"
  if [[ "$current" != "$new_state" ]]; then
    soviez_stage_sm_assert "$current" "$new_state"
  fi
  soviez_json_merge_file "$state_file" "$(SOVIEZ_NEW_STATE="$new_state" SOVIEZ_META="$meta_json" python3 - <<'PY'
import json, os, time
patch = {"state": os.environ["SOVIEZ_NEW_STATE"], "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
meta = json.loads(os.environ.get("SOVIEZ_META", "{}"))
if meta:
    patch.update(meta)
print(json.dumps(patch))
PY
)"
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    local env_id
    env_id="$(soviez_json_get "$(cat "$state_file")" stage_id 2>/dev/null || true)"
    [[ -n "$env_id" ]] || env_id="$(soviez_json_get "$(cat "$state_file")" environment_id 2>/dev/null || true)"
    if ! soviez_ops_sync_transition "$op_id" stage_create "$env_id" "$new_state" "transition" "$meta_json" "$state_file"; then
      soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_PENDING
      case "$new_state" in
        database_restoring|database_restore|filestore_cloning|neutralization_running)
          soviez_stage_die STAGE_OPERATION_FAILED "Canonical sync failed before protected Stage step: $new_state"
          ;;
      esac
    fi
  fi
}

soviez_stage_op_merge() {
  local op_id="$1"
  local patch="$2"
  soviez_json_merge_file "$(soviez_stage_op_state_file "$op_id")" "$patch"
}
