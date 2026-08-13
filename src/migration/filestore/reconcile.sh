# shellcheck shell=bash

soviez_migration_filestore_reconcile() {
  local op_id="$1" staging_id="$2"
  local delta staging_fs
  delta="$(soviez_migration_transfer_op_dir "$op_id")/filestore/delta.json"
  staging_fs="$(soviez_migration_staging_dir "$staging_id")/filestore"
  mkdir -p "$staging_fs"
  if [[ -f "$delta" ]]; then
    SOVIEZ_D="$delta" SOVIEZ_FS="$staging_fs" python3 - <<'PY'
import json, os, pathlib
d=json.loads(open(os.environ["SOVIEZ_D"]).read())
root=pathlib.Path(os.environ["SOVIEZ_FS"])
for item in d.get("deleted") or []:
  p=root / item["path"]
  if p.exists() and p.is_file():
    # exact delete only under staging filestore
    try:
      p.resolve().relative_to(root.resolve())
      p.unlink()
    except Exception:
      pass
print(json.dumps({"status":"reconciled","deleted": len(d.get("deleted") or [])}, separators=(",", ":")))
PY
  else
    printf '{"status":"reconciled","deleted":0}\n'
  fi
}
