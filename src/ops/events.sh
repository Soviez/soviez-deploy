# shellcheck shell=bash

soviez_ops_append_event() {
  local op_id="$1" event_type="$2" message="$3" extra_json="${4:-{}}" record seq events
  record="$(cat "$(soviez_ops_canonical_state_path "$op_id")")" || soviez_ops_die OPERATION_NOT_FOUND "Unknown operation: $op_id"
  seq="$(soviez_json_get "$record" sequence 2>/dev/null || printf '0')"
  events="$(soviez_ops_events_path "$op_id")"
  mkdir -p "$(dirname "$events")"; chmod 700 "$(dirname "$events")"
  SOVIEZ_EVT_TYPE="$event_type" SOVIEZ_EVT_MSG="$(soviez_redact_text "$message")" \
    SOVIEZ_EVT_EXTRA="$(soviez_redact_text "$extra_json")" SOVIEZ_EVT_SEQ="$((seq + 1))" \
    python3 - <<'PY' >> "$events"
import json, os, time
try: extra=json.loads(os.environ["SOVIEZ_EVT_EXTRA"])
except Exception: extra={}
print(json.dumps({"sequence":int(os.environ["SOVIEZ_EVT_SEQ"]), "at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
 "event_type":os.environ["SOVIEZ_EVT_TYPE"],"message":os.environ["SOVIEZ_EVT_MSG"],"extra":extra},separators=(",",":")))
PY
  chmod 600 "$events"
}
