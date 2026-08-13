#!/usr/bin/env bash
# S6 — full restore depth: synthetic backup integrity, corrupt FAIL, S4 for untrusted, filestore list.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-restore.XXXXXX")}"
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-q.XXXXXX")"
ev="$(s6_evidence_init "$(s6_run_id)")"
BACKUP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-bk.XXXXXX")"
trap 'rm -rf "$BACKUP_ROOT" "$SOVIEZ_SEC_QUARANTINE_ROOT"; [[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"' EXIT

bdir="$BACKUP_ROOT/snap1"
mkdir -p "$bdir/filestore_src/documents" "$bdir/filestore_src/attachments"
printf 'PGDUMP-S6-FAKE\n' >"$bdir/db.dump"
echo 'doc-one' >"$bdir/filestore_src/documents/a.txt"
echo 'att-two' >"$bdir/filestore_src/attachments/b.bin"
(
  cd "$bdir/filestore_src"
  tar -czf "$bdir/filestore.tar.gz" .
)
printf '{"version":1,"gate":"S6","filestore_files":["./documents/a.txt","./attachments/b.bin"]}\n' >"$bdir/manifest.json"

{
  echo "db.dump=$(s6_hash_file "$bdir/db.dump")"
  echo "filestore.tar.gz=$(s6_hash_file "$bdir/filestore.tar.gz")"
  echo "manifest.json=$(s6_hash_file "$bdir/manifest.json")"
} >"$bdir/checksums.txt"

integ="$(soviez_s5_backup_integrity_verify "$bdir")"
[[ "$integ" == "PASS" ]] || { echo "FAIL integrity expected PASS" >&2; exit 1; }
echo "OK integrity PASS"

# Corrupt → FAIL
echo corrupt >>"$bdir/db.dump"
set +e
integ_bad="$(soviez_s5_backup_integrity_verify "$bdir" 2>/dev/null)"
integ_rc=$?
set -e
[[ "$integ_bad" == "FAIL" && "$integ_rc" -ne 0 ]] || { echo "FAIL corrupt expected FAIL" >&2; exit 1; }
# Restore good dump + checksums
printf 'PGDUMP-S6-FAKE\n' >"$bdir/db.dump"
{
  echo "db.dump=$(s6_hash_file "$bdir/db.dump")"
  echo "filestore.tar.gz=$(s6_hash_file "$bdir/filestore.tar.gz")"
  echo "manifest.json=$(s6_hash_file "$bdir/manifest.json")"
} >"$bdir/checksums.txt"
echo "OK integrity FAIL on corrupt"

# Restore verify requires S4 for untrusted
needs="$(soviez_s5_restore_verify_requires_s4 EXTERNAL_UNKNOWN)"
[[ "$needs" == "true" ]] || { echo "FAIL expected requires_s4=true" >&2; exit 1; }
rv="$(soviez_s5_restore_verify "$bdir" EXTERNAL_UNKNOWN)"
[[ "$rv" == "PASS" ]] || { echo "FAIL restore_verify with S4 expected PASS got $rv" >&2; exit 1; }

# Fail closed when S4 helpers unavailable
set +e
fc="$(
  bash -c '
    set +e
    source "'"$ROOT"'/src/security/backup_safety/restore_verify.sh"
    soviez_s5_restore_verify /tmp EXTERNAL_UNKNOWN 2>/dev/null
  '
)"
set -e
[[ "$fc" == "FAIL" ]] || { echo "FAIL expected fail-closed without S4" >&2; exit 1; }
echo "OK restore_verify requires S4 / fail closed"

# Filestore extract consistency — list files match
extract="$ev/artifacts/filestore_extract"
mkdir -p "$extract"
tar -tzf "$bdir/filestore.tar.gz" | sed 's|^\./||' | grep -vE '^$|/$' | sort >"$extract/listed.txt"
expected=$'attachments/b.bin\ndocuments/a.txt'
actual="$(cat "$extract/listed.txt")"
[[ "$actual" == "$expected" ]] || {
  echo "FAIL filestore list mismatch" >&2
  printf 'expected:\n%s\n' "$expected" >&2
  printf 'actual:\n%s\n' "$actual" >&2
  exit 1
}
tar -xzf "$bdir/filestore.tar.gz" -C "$extract"
[[ -f "$extract/documents/a.txt" && -f "$extract/attachments/b.bin" ]]
[[ "$(cat "$extract/documents/a.txt")" == "doc-one" ]]
echo "OK filestore extract consistency"

s6_write_json "$ev/findings/restore_depth.json" "$(cat <<EOF
{
  "status": "PASS",
  "integrity_pass": true,
  "integrity_corrupt_fail": true,
  "restore_requires_s4_untrusted": true,
  "filestore_files": ["attachments/b.bin", "documents/a.txt"]
}
EOF
)"
echo PASS
