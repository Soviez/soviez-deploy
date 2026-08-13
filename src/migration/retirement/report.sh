# shellcheck shell=bash

soviez_migration_p22_retirement_report() {
  local source_id="$1"
  local out
  out="$(soviez_migration_p22_retirement_dir "$source_id")/report.json"
  mkdir -p "$(dirname "$out")"
  local ready inv
  ready="$(soviez_migration_p22_retirement_readiness "$source_id")"
  inv="$(soviez_migration_p22_retirement_inventory "$source_id")"
  SOVIEZ_OUT="$out" SOVIEZ_READY="$ready" SOVIEZ_INV="$inv" SOVIEZ_SID="$source_id" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_retirement.v1",
  "source_id": os.environ["SOVIEZ_SID"],
  "readiness": json.loads(os.environ["SOVIEZ_READY"]),
  "inventory": json.loads(os.environ["SOVIEZ_INV"]),
  "manual": {"automated_purge": False},
  "provider": {"host_termination_authorized": False},
  "created_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
