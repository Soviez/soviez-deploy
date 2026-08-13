# shellcheck shell=bash

soviez_ops_paths_init() {
  : "${SOVIEZ_OPS_ROOT:?soviez_paths_init must run first}"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    SOVIEZ_OPS_REGISTRY_DIR="$SOVIEZ_OPS_ROOT/registry"
  else
    SOVIEZ_OPS_REGISTRY_DIR="${SOVIEZ_OPS_REGISTRY_DIR:-$SOVIEZ_OPS_ROOT/registry}"
  fi
  SOVIEZ_OPS_INDEX_DIR="$SOVIEZ_OPS_REGISTRY_DIR/index"
  SOVIEZ_OPS_LOCKS_DIR="$SOVIEZ_OPS_REGISTRY_DIR/locks"
  SOVIEZ_OPS_HISTORY_DIR="$SOVIEZ_OPS_REGISTRY_DIR/history"
  SOVIEZ_OPS_CANONICAL_NAME=canonical.json
  export SOVIEZ_OPS_REGISTRY_DIR SOVIEZ_OPS_INDEX_DIR SOVIEZ_OPS_LOCKS_DIR SOVIEZ_OPS_HISTORY_DIR SOVIEZ_OPS_CANONICAL_NAME
  mkdir -p "$SOVIEZ_OPS_INDEX_DIR" "$SOVIEZ_OPS_LOCKS_DIR" "$SOVIEZ_OPS_HISTORY_DIR"
  chmod 700 "$SOVIEZ_OPS_REGISTRY_DIR" "$SOVIEZ_OPS_INDEX_DIR" "$SOVIEZ_OPS_LOCKS_DIR" "$SOVIEZ_OPS_HISTORY_DIR"
}

soviez_ops_registry_index_path() { printf '%s/%s.json\n' "$SOVIEZ_OPS_INDEX_DIR" "$1"; }
soviez_ops_resource_lock_path() { printf '%s/%s.lock\n' "$SOVIEZ_OPS_LOCKS_DIR" "$1"; }
soviez_ops_history_path() { printf '%s/%s.jsonl\n' "$SOVIEZ_OPS_HISTORY_DIR" "$1"; }

# Resolve the on-disk directory for an operation across Phase 8/11/12/13 roots.
soviez_ops_resolve_dir() {
  local op_id="$1" idx cpath candidate
  idx="$(soviez_ops_registry_index_path "$op_id")"
  if [[ -f "$idx" ]]; then
    cpath="$(soviez_json_get "$(cat "$idx")" canonical_path 2>/dev/null || true)"
    if [[ -n "$cpath" && -f "$cpath" ]]; then
      dirname "$cpath"
      return 0
    fi
  fi
  for candidate in \
    "$(soviez_operation_dir "$op_id")" \
    "${SOVIEZ_STAGE_OPS_DIR:-$SOVIEZ_OPS_ROOT/stage-operations}/$op_id" \
    "${SOVIEZ_SSL_OPS_DIR:-$SOVIEZ_OPS_ROOT/ssl-operations}/$op_id"; do
    [[ -d "$candidate" ]] || continue
    if [[ -f "$candidate/$SOVIEZ_OPS_CANONICAL_NAME" || -f "$candidate/state.json" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$(soviez_operation_dir "$op_id")"
}

soviez_ops_canonical_state_path() { printf '%s/%s\n' "$(soviez_ops_resolve_dir "$1")" "$SOVIEZ_OPS_CANONICAL_NAME"; }
soviez_ops_events_path() { printf '%s/events.jsonl\n' "$(soviez_ops_resolve_dir "$1")"; }
soviez_ops_heartbeat_path() { printf '%s/heartbeat\n' "$(soviez_ops_resolve_dir "$1")"; }
