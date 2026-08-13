# shellcheck shell=bash
# Security Gate S5 — backup integrity via checksums.txt.

soviez_s5_backup_integrity_verify() {
  local dir="$1"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo FAIL
    return 1
  fi
  local cs="$dir/checksums.txt"
  if [[ ! -f "$cs" ]]; then
    echo FAIL
    return 1
  fi

  if [[ "${SOVIEZ_S5_BACKUP_INJECT_CORRUPT:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  python3 - "$dir" "$cs" <<'PY'
import hashlib,os,sys
d,cs=sys.argv[1],sys.argv[2]
# Support "name=hex" and "hex  path" formats.
errors=[]
for line in open(cs):
  line=line.strip()
  if not line or line.startswith("#"):
    continue
  path=None
  expected=None
  if "=" in line and not line.split("=",1)[0].strip().startswith("sha"):
    name,expected=line.split("=",1)
    name=name.strip(); expected=expected.strip()
    candidates=[
      os.path.join(d,name),
      os.path.join(d,name+".dump"),
      os.path.join(d,"db.dump" if name=="db" else name),
      os.path.join(d,"db.dump.enc" if name=="db" else name),
      os.path.join(d,"filestore.tar.gz" if name=="filestore" else name),
      os.path.join(d,"filestore.tar.zst" if name=="filestore" else name),
      os.path.join(d,"manifest.json" if name=="manifest" else name),
    ]
    for c in candidates:
      if os.path.isfile(c):
        path=c; break
    if path is None:
      # try exact relative under dir
      p=os.path.join(d,name)
      if os.path.isfile(p): path=p
  else:
    parts=line.split()
    if len(parts)>=2:
      expected=parts[0]
      path=parts[-1]
      if not os.path.isabs(path):
        path=os.path.join(d,path)
  if not path or not os.path.isfile(path):
    errors.append(f"missing:{line}")
    continue
  h=hashlib.sha256()
  with open(path,"rb") as f:
    for chunk in iter(lambda:f.read(1024*1024),b""):
      h.update(chunk)
  actual=h.hexdigest()
  exp=expected.lower()
  if exp.startswith("sha256:"):
    exp=exp[7:]
  if actual.lower()!=exp:
    errors.append(f"mismatch:{path}")
if errors:
  print("FAIL")
  sys.exit(1)
print("PASS")
PY
}
