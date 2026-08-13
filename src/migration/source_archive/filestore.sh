# shellcheck shell=bash

soviez_migration_p22_archive_filestore() {
  local op_id="$1" source_root="${2:-}"
  source_root="${source_root:-${SOVIEZ_MIG_P22_SOURCE_FILESTORE:-${SOVIEZ_MIG_P22_SOURCE_ROOT:-}}}"
  [[ -n "$source_root" && -d "$source_root" ]] || \
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "filestore root required"

  local out_dir tar_path manifest
  out_dir="$(soviez_migration_p22_archive_op_dir "$op_id")/filestore"
  mkdir -p "$out_dir"
  tar_path="$out_dir/filestore.tar"
  manifest="$out_dir/manifest.json"

  # Pre-scan: deny symlink escape, path traversal, device, fifo.
  SOVIEZ_ROOT="$source_root" python3 - <<'PY'
import os, sys, stat
root=os.path.realpath(os.environ["SOVIEZ_ROOT"])
for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
  for name in dirnames + filenames:
    p=os.path.join(dirpath, name)
    rel=os.path.relpath(p, root)
    if ".." in rel.split(os.sep):
      print("path traversal", rel, file=sys.stderr); sys.exit(2)
    st=os.lstat(p)
    if stat.S_ISLNK(st.st_mode):
      target=os.path.realpath(p)
      if not (target==root or target.startswith(root+os.sep)):
        print("symlink escape", rel, file=sys.stderr); sys.exit(3)
    if stat.S_ISCHR(st.st_mode) or stat.S_ISBLK(st.st_mode) or stat.S_ISFIFO(st.st_mode) or stat.S_ISSOCK(st.st_mode):
      print("special file denied", rel, file=sys.stderr); sys.exit(4)
print("ok")
PY
  [[ $? -eq 0 ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "filestore safety scan failed"

  # Create tar with relative paths only.
  (
    cd "$source_root"
    tar -cf "$tar_path" .
  ) || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "filestore tar failed"

  SOVIEZ_OUT="$manifest" SOVIEZ_ROOT="$source_root" SOVIEZ_TAR="$tar_path" python3 - <<'PY'
import json, os, hashlib, tarfile
root=os.environ["SOVIEZ_ROOT"]
entries=[]
with tarfile.open(os.environ["SOVIEZ_TAR"], "r:") as tf:
  for m in tf.getmembers():
    if not m.isfile():
      continue
    if m.name.startswith("/") or ".." in m.name.split("/"):
      raise SystemExit("unsafe tar member")
    f=tf.extractfile(m)
    data=f.read() if f else b""
    entries.append({"path": m.name.lstrip("./"), "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
tar_sha=hashlib.sha256(open(os.environ["SOVIEZ_TAR"],"rb").read()).hexdigest()
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "file_count": len(entries),
  "files": entries,
  "tar_sha256": tar_sha,
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
