# shellcheck shell=bash

soviez_migration_filestore_inventory() {
  local pair_id="$1" root="${2:-}"
  if [[ -z "$root" ]]; then
    root="${SOVIEZ_MIG_FIXTURE_FILESTORE:-}"
  fi
  if [[ -z "$root" ]]; then
    # Synthetic inventory for fixtures
    printf '{"root":"","file_count":0,"total_bytes":0,"files":[]}\n'
    return 0
  fi
  SOVIEZ_ROOTFS="$root" python3 - <<'PY'
import json, os, hashlib, pathlib
root=pathlib.Path(os.environ["SOVIEZ_ROOTFS"])
files=[]
total=0
if root.exists():
  for p in sorted(root.rglob("*")):
    if not p.is_file(): continue
    # path traversal / symlink escape prevention
    try:
      rp=p.resolve(); root.resolve().relative_to(root.resolve())  # noqa
      rp.relative_to(root.resolve())
    except Exception:
      continue
    if p.is_symlink():
      continue
    data=p.read_bytes()
    total += len(data)
    files.append({
      "path": str(p.relative_to(root)),
      "size_bytes": len(data),
      "sha256": hashlib.sha256(data).hexdigest(),
    })
print(json.dumps({"root": str(root), "file_count": len(files), "total_bytes": total, "files": files}, separators=(",", ":")))
PY
}
