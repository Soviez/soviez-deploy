# shellcheck shell=bash
# Security Gate S4 — archive extraction safety (fail-closed).

soviez_q_archive_validate() {
  local archive="$1" dest="$2"
  [[ -f "$archive" ]] || { echo "[error] security:SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL: archive missing" >&2; return 1; }
  mkdir -p "$dest"
  python3 - "$archive" "$dest" <<'PY'
import os,sys,tarfile,zipfile,stat
archive,dest=sys.argv[1],sys.argv[2]
dest=os.path.realpath(dest)

def bad(code, msg):
  print(f"[error] security:{code}: {msg}", file=sys.stderr)
  raise SystemExit(1)

def check_member(name, is_symlink=False, linkname="", is_hardlink=False, is_dev=False):
  if name.startswith("/") or name.startswith("\\"):
    bad("SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL", "absolute path")
  parts=name.replace("\\","/").split("/")
  if ".." in parts:
    bad("SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL", "path traversal")
  target=os.path.realpath(os.path.join(dest, name))
  if not (target==dest or target.startswith(dest+os.sep)):
    bad("SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL", "escapes destination")
  if is_symlink or is_hardlink:
    ln=linkname or ""
    if ln.startswith("/") or ".." in ln.replace("\\","/").split("/"):
      bad("SEC_CRIT_RESTORE_SYMLINK_ESCAPE", "link escape")
    base=os.path.dirname(os.path.join(dest, name))
    resolved=os.path.realpath(os.path.join(base, ln)) if ln else dest
    if not (resolved==dest or resolved.startswith(dest+os.sep)):
      bad("SEC_CRIT_RESTORE_SYMLINK_ESCAPE", "link outside dest")
  if is_dev:
    bad("SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL", "device node")

if tarfile.is_tarfile(archive):
  with tarfile.open(archive, "r:*") as tf:
    for m in tf.getmembers():
      is_dev = m.isdev() if hasattr(m,"isdev") else False
      if not is_dev:
        try:
          is_dev = stat.S_ISCHR(m.mode) or stat.S_ISBLK(m.mode) or stat.S_ISFIFO(m.mode)
        except Exception:
          is_dev=False
      check_member(m.name, m.issym(), m.linkname if (m.issym() or m.islnk()) else "", m.islnk(), is_dev)
  print("PASS_TAR")
elif zipfile.is_zipfile(archive):
  with zipfile.ZipFile(archive) as zf:
    for info in zf.infolist():
      check_member(info.filename)
  print("PASS_ZIP")
else:
  print("PASS_OPAQUE")
PY
}

soviez_q_archive_extract_safe() {
  local archive="$1" dest="$2"
  soviez_q_archive_validate "$archive" "$dest" || return 1
  local need avail
  need="$(du -k "$archive" 2>/dev/null | awk '{print $1*3}')"
  avail="$(df -k "$dest" 2>/dev/null | awk 'NR==2{print $4}')"
  if [[ -n "$need" && -n "$avail" && "$avail" -lt "$need" ]]; then
    echo "[error] security:SEC_CRIT_RESTORE_ARCHIVE_TRAVERSAL: insufficient disk" >&2
    return 1
  fi
  python3 - "$archive" "$dest" <<'PY'
import os,sys,tarfile,zipfile
archive,dest=sys.argv[1],sys.argv[2]
os.makedirs(dest, exist_ok=True)
if tarfile.is_tarfile(archive):
  with tarfile.open(archive,"r:*") as tf:
    try:
      tf.extractall(dest, filter="data")
    except TypeError:
      tf.extractall(dest)
elif zipfile.is_zipfile(archive):
  with zipfile.ZipFile(archive) as zf:
    zf.extractall(dest)
print(dest)
PY
}
