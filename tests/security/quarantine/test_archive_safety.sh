#!/usr/bin/env bash
# Archive extraction safety — traversal/symlink/absolute/device rejected.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s4_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
dest="$tmp/out"
mkdir -p "$dest"

# Good archive
mkdir -p "$tmp/good/data"
echo ok >"$tmp/good/data/file.txt"
( cd "$tmp/good" && tar czf "$tmp/good.tgz" data )
soviez_q_archive_validate "$tmp/good.tgz" "$dest" | grep -q PASS
soviez_q_archive_extract_safe "$tmp/good.tgz" "$dest/extract" >/dev/null
[[ -f "$dest/extract/data/file.txt" ]]

# Traversal
mkdir -p "$tmp/trav"
echo evil >"$tmp/trav/x"
( cd "$tmp/trav" && tar cf "$tmp/trav.tar" --transform 's|^x|../../escape|' x 2>/dev/null ) || \
  python3 - "$tmp/trav.tar" <<'PY'
import tarfile,io,sys
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("../../escape")
info.size=4
tf.addfile(info, io.BytesIO(b"evil"))
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/trav.tar" "$dest/t2" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]

# Absolute path
python3 - "$tmp/abs.tar" <<'PY'
import tarfile,io,sys
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("/etc/passwd.evil")
info.size=1
tf.addfile(info, io.BytesIO(b"x"))
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/abs.tar" "$dest/t3" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]

# Symlink escape
python3 - "$tmp/sym.tar" <<'PY'
import tarfile,sys
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("link")
info.type=tarfile.SYMTYPE
info.linkname="/etc/passwd"
tf.addfile(info)
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/sym.tar" "$dest/t4" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]

# Hardlink escape
python3 - "$tmp/hard.tar" <<'PY'
import tarfile,sys
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("h")
info.type=tarfile.LNKTYPE
info.linkname="/etc/passwd"
tf.addfile(info)
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/hard.tar" "$dest/t5" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]

# Device node
python3 - "$tmp/dev.tar" <<'PY'
import tarfile,sys,stat
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("devnode")
info.type=tarfile.CHRTYPE
info.mode=stat.S_IFCHR | 0o666
info.devmajor=1
info.devminor=3
tf.addfile(info)
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/dev.tar" "$dest/t6" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]

echo PASS
