# shellcheck shell=bash

soviez_migration_filestore_manifest_write() {
  local op_id="$1" inventory_json="$2" generation="${3:-0}"
  local out
  out="$(soviez_migration_transfer_op_dir "$op_id")/filestore/manifest_gen${generation}.json"
  mkdir -p "$(dirname "$out")"
  SOVIEZ_I="$inventory_json" SOVIEZ_G="$generation" SOVIEZ_O="$out" python3 - <<'PY'
import json, os, datetime
inv=json.loads(os.environ["SOVIEZ_I"])
doc={
  "schema_version":"soviez.migration_filestore_manifest.v1",
  "generation": int(os.environ["SOVIEZ_G"]),
  "root": inv.get("root"),
  "file_count": inv.get("file_count"),
  "total_bytes": inv.get("total_bytes"),
  "files": inv.get("files") or [],
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.environ["SOVIEZ_O"],"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY
}
