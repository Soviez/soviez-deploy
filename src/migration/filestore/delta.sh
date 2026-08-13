# shellcheck shell=bash

soviez_migration_filestore_delta() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local prev new_inv delta_path
  prev="$(soviez_migration_transfer_op_dir "$op_id")/filestore/manifest_gen1.json"
  new_inv="$(soviez_migration_filestore_inventory "$pair_id")"
  soviez_migration_filestore_manifest_write "$op_id" "$new_inv" 2 >/dev/null
  delta_path="$(soviez_migration_transfer_op_dir "$op_id")/filestore/delta.json"
  SOVIEZ_PREV="${prev}" SOVIEZ_NEW="$new_inv" SOVIEZ_OUT="$delta_path" python3 - <<'PY'
import json, os, pathlib
prev={}
p=os.environ.get("SOVIEZ_PREV") or ""
if p and pathlib.Path(p).exists():
  prev=json.loads(pathlib.Path(p).read_text())
new=json.loads(os.environ["SOVIEZ_NEW"])
prev_map={f["path"]:f for f in (prev.get("files") or [])}
new_map={f["path"]:f for f in (new.get("files") or [])}
changed=[]; added=[]; deleted=[]
for path,f in new_map.items():
  if path not in prev_map:
    added.append(f)
  elif prev_map[path].get("sha256")!=f.get("sha256"):
    changed.append(f)
for path in prev_map:
  if path not in new_map:
    deleted.append({"path": path})
doc={"changed":changed,"added":added,"deleted":deleted,"generation":2}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY
}
