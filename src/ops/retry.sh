# shellcheck shell=bash

soviez_ops_retry() {
  local op_id="$1" yes="${2:-}" path record state updated
  path="$(soviez_ops_canonical_state_path "$op_id")"; record="$(cat "$path")" || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  state="$(soviez_json_get "$record" current_state)"
  [[ "$state" == failed_retryable || "$state" == recovery_required ]] || soviez_ops_die OPERATION_RETRY_NOT_ALLOWED "Retry not permitted for $state"
  updated="$(SOVIEZ_REC="$record" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_REC"]); d["retry_count"]=int(d.get("retry_count",0))+1; print(json.dumps(d,separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$path" "$updated"
  soviez_ops_transition "$op_id" retry_scheduled
  soviez_ops_transition "$op_id" starting
}
