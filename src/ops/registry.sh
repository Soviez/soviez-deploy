# shellcheck shell=bash

soviez_ops_registry_register() {
  local op_id="$1" canonical summary
  canonical="$(soviez_ops_canonical_state_path "$op_id")"; [[ -f "$canonical" ]] || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  summary="$(SOVIEZ_CANONICAL="$(cat "$canonical")" SOVIEZ_PATH="$canonical" python3 - <<'PY'
import json, os
d=json.loads(os.environ["SOVIEZ_CANONICAL"])
keys=("operation_id","operation_type","environment_id","current_state","current_checkpoint","updated_at","heartbeat_at",
      "canonical_sync_status","canonical_state_revision","registry_revision","sequence")
out={k:d.get(k) for k in keys}
out["canonical_path"]=os.environ["SOVIEZ_PATH"]
out["registry_revision"]=d.get("registry_revision") or d.get("canonical_state_revision") or d.get("sequence") or 0
print(json.dumps(out,separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_ops_registry_index_path "$op_id")" "$summary"
}
soviez_ops_registry_unregister() { rm -f "$(soviez_ops_registry_index_path "$1")"; }
soviez_ops_registry_get() { cat "$(soviez_ops_registry_index_path "$1")" 2>/dev/null || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $1"; }
soviez_ops_registry_list() {
  local flag="${1:-}" value="${2:-}" f record state
  for f in "$SOVIEZ_OPS_INDEX_DIR"/*.json; do
    [[ -f "$f" ]] || continue; record="$(cat "$f")"; state="$(soviez_json_get "$record" current_state)"
    case "$flag" in --active) [[ "$state" =~ ^(completed|canceled|failed_terminal)$ ]] && continue ;; --failed) [[ "$state" == failed_* || "$state" == recovery_required ]] || continue ;; --environment) [[ "$(soviez_json_get "$record" environment_id)" == "$value" ]] || continue ;; --type) [[ "$(soviez_json_get "$record" operation_type)" == "$value" ]] || continue ;; esac
    printf '%s\n' "$record"
  done
}
soviez_ops_registry_reconcile_index() {
  local dir canonical
  for dir in "$SOVIEZ_OPS_ROOT/operations"/* "$SOVIEZ_STAGE_OPS_DIR"/* "$SOVIEZ_SSL_OPS_DIR"/*; do
    [[ -d "$dir" ]] || continue; canonical="$dir/$SOVIEZ_OPS_CANONICAL_NAME"
    [[ -f "$canonical" ]] || soviez_ops_migrate_one "$dir" >/dev/null 2>&1 || continue
    soviez_ops_registry_register "$(soviez_json_get "$(cat "$canonical")" operation_id)"
  done
}
