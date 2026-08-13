# shellcheck shell=bash

soviez_migration_p22_archive_state_write() {
  local op_id="$1" state="$2"
  local source_id="${3:-}" cutover_id="${4:-}" auth_id="${5:-}" more_json="${6:-{}}"
  local f
  f="$(soviez_migration_p22_archive_state_path "$op_id")"
  mkdir -p "$(dirname "$f")"
  SOVIEZ_OUT="$f" SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" \
  SOVIEZ_SID="$source_id" SOVIEZ_CID="$cutover_id" SOVIEZ_AID="$auth_id" \
  SOVIEZ_MORE="$more_json" python3 - <<'PY'
import json, os
existing={}
try:
  existing=json.load(open(os.environ["SOVIEZ_OUT"]))
except Exception:
  existing={}
existing.update({
  "operation_id": os.environ["SOVIEZ_OP"],
  "current_state": os.environ["SOVIEZ_ST"],
})
if os.environ.get("SOVIEZ_SID"):
  existing["source_id"] = os.environ["SOVIEZ_SID"]
if os.environ.get("SOVIEZ_CID"):
  existing["cutover_id"] = os.environ["SOVIEZ_CID"]
if os.environ.get("SOVIEZ_AID"):
  existing["authorization_id"] = os.environ["SOVIEZ_AID"]
more_raw = os.environ.get("SOVIEZ_MORE") or "{}"
try:
  more = json.loads(more_raw)
  if isinstance(more, dict):
    existing.update(more)
except Exception:
  pass
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(existing, separators=(",", ":")))
PY
  cat "$f"
}
