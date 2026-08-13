# shellcheck shell=bash

soviez_ops_heartbeat_touch() {
  local op_id="$1" now path record updated
  now="$(soviez_ops_now_utc)"; path="$(soviez_ops_heartbeat_path "$op_id")"
  printf '%s\n' "$now" > "$path"; chmod 600 "$path"
  record="$(cat "$(soviez_ops_canonical_state_path "$op_id")")" || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  updated="$(SOVIEZ_CURRENT="$record" SOVIEZ_NOW="$now" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CURRENT"]); d["heartbeat_at"]=os.environ["SOVIEZ_NOW"]; print(json.dumps(d,separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path "$op_id")" "$updated"
}

soviez_ops_heartbeat_stale() {
  local op_id="$1" threshold="${2:-120}" path
  path="$(soviez_ops_heartbeat_path "$op_id")"; [[ -f "$path" ]] || return 0
  SOVIEZ_HEARTBEAT="$(cat "$path")" SOVIEZ_THRESHOLD="$threshold" python3 - <<'PY'
import datetime, os, sys
try: stamp=datetime.datetime.strptime(os.environ["SOVIEZ_HEARTBEAT"].strip(),"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
except ValueError: raise SystemExit(0)
raise SystemExit(0 if (datetime.datetime.now(datetime.timezone.utc)-stamp).total_seconds()>int(os.environ["SOVIEZ_THRESHOLD"]) else 1)
PY
}
