# shellcheck shell=bash

soviez_migration_p22_archive_inventory() {
  local op_id="$1" source_root="${2:-}"
  source_root="${source_root:-${SOVIEZ_MIG_P22_SOURCE_ROOT:-}}"
  [[ -n "$source_root" && -d "$source_root" ]] || \
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "source root required"
  local out
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/inventory.json"
  mkdir -p "$(dirname "$out")"
  SOVIEZ_OUT="$out" SOVIEZ_ROOT="$source_root" python3 - <<'PY'
import json, os, hashlib
root=os.environ["SOVIEZ_ROOT"]
files=[]
for dirpath, dirnames, filenames in os.walk(root):
  # deny traversal escapes later; skip special dirs
  for fn in filenames:
    p=os.path.join(dirpath, fn)
    rel=os.path.relpath(p, root)
    if rel.startswith(".."):
      continue
    st=os.lstat(p)
    if os.path.islink(p) or not os.path.isfile(p):
      continue
    h=hashlib.sha256(open(p,"rb").read()).hexdigest()
    files.append({"path":rel.replace("\\\\","/"),"size":st.st_size,"sha256":h})
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "source_root": root,
  "file_count": len(files),
  "files": files,
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
