#!/usr/bin/env bash
# S5 backup integrity, posture, secrets, retention, disk, restore, encryption.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
if [[ -f "$ROOT/dist/soviez.sh" ]] && ! grep -q 'soviez_s5_backup_integrity_verify' "$ROOT/dist/soviez.sh" 2>/dev/null; then
  BAK="$ROOT/dist/soviez.sh.s5bak.$$"
  mv "$ROOT/dist/soviez.sh" "$BAK"
else
  BAK=""
fi
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SEC_S5_EVIDENCE_ROOT
SOVIEZ_SEC_S5_EVIDENCE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s5-evid.XXXXXX")"
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s4-q.XXXXXX")"
trap '
  rm -rf "$SOVIEZ_SEC_S5_EVIDENCE_ROOT" "$SOVIEZ_SEC_QUARANTINE_ROOT" "${BACKUP_ROOT:-}"
  if [[ -n "${BAK:-}" && -f "$BAK" ]]; then mv "$BAK" "$ROOT/dist/soviez.sh"; fi
' EXIT

BACKUP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s5-bk.XXXXXX")"
bdir="$BACKUP_ROOT/snap1"
mkdir -p "$bdir"

printf 'PGDUMP-FAKE\n' >"$bdir/db.dump"
printf 'filestore-fake\n' >"$bdir/filestore.tar.gz"
printf '{"version":1,"gate":"S5"}\n' >"$bdir/manifest.json"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

{
  echo "db.dump=$(sha256_file "$bdir/db.dump")"
  echo "filestore.tar.gz=$(sha256_file "$bdir/filestore.tar.gz")"
  echo "manifest.json=$(sha256_file "$bdir/manifest.json")"
} >"$bdir/checksums.txt"

# integrity PASS
integ="$(soviez_s5_backup_integrity_verify "$bdir")"
[[ "$integ" == "PASS" ]]
echo "OK integrity PASS"

# corrupt → FAIL
echo corrupt >>"$bdir/db.dump"
set +e
integ_bad="$(soviez_s5_backup_integrity_verify "$bdir" 2>/dev/null)"
integ_rc=$?
set -e
[[ "$integ_bad" == "FAIL" ]]
[[ "$integ_rc" -ne 0 ]]
# restore good dump for later checks
printf 'PGDUMP-FAKE\n' >"$bdir/db.dump"
{
  echo "db.dump=$(sha256_file "$bdir/db.dump")"
  echo "filestore.tar.gz=$(sha256_file "$bdir/filestore.tar.gz")"
  echo "manifest.json=$(sha256_file "$bdir/manifest.json")"
} >"$bdir/checksums.txt"
echo "OK integrity FAIL on corrupt"

# LOCAL_ONLY → dr_capable false
class_local="$(soviez_s5_backup_classify_destination local)"
[[ "$class_local" == "LOCAL_ONLY" ]]
set +e
dr_local="$(soviez_s5_backup_dr_capable LOCAL_ONLY 2>/dev/null)"
dr_rc=$?
set -e
[[ "$dr_local" == "false" ]]
[[ "$dr_rc" -ne 0 ]]
echo "OK LOCAL_ONLY dr_capable=false"

# s3/sftp → true
[[ "$(soviez_s5_backup_classify_destination s3://bucket/x)" == "OFF_HOST_S3_COMPATIBLE" ]]
[[ "$(soviez_s5_backup_dr_capable OFF_HOST_S3_COMPATIBLE)" == "true" ]]
[[ "$(soviez_s5_backup_classify_destination sftp://fixture/path)" == "OFF_HOST_SFTP" ]]
[[ "$(soviez_s5_backup_dr_capable OFF_HOST_SFTP)" == "true" ]]
echo "OK off-host DR capable"

# secret_scan finds unnecessary docker config.json with auth
mkdir -p "$bdir/.docker"
printf '{"auths":{"https://index.docker.io/v1/":{"auth":"dXNlcjpwYXNz"}}}\n' \
  >"$bdir/.docker/config.json"
set +e
sec="$(soviez_s5_backup_secret_scan "$bdir" 2>/dev/null)"
sec_rc=$?
set -e
[[ "$sec" == "UNNECESSARY" ]]
[[ "$sec_rc" -ne 0 ]]
rm -rf "$bdir/.docker"
echo "OK secret_scan UNNECESSARY docker auth"

# retention respects PRESERVE marker
keep="$BACKUP_ROOT/keep-me"
drop="$BACKUP_ROOT/drop-me"
mkdir -p "$keep" "$drop"
touch "$keep/PRESERVE" "$drop/x"
# force max_keep=1 so drop-me would be removed if not preserved ordering
# With sort: drop-me before keep-me alphabetically; PRESERVE skips keep-me from dirs list
# dirs without PRESERVE: only drop-me → n=1, max_keep=1 → no drop by count
# Create many non-preserve dirs then one PRESERVE
for i in 1 2 3; do mkdir -p "$BACKUP_ROOT/old$i"; echo x >"$BACKUP_ROOT/old$i/f"; done
export SOVIEZ_S5_BACKUP_RETENTION_MAX=2
export SOVIEZ_S5_BACKUP_RETENTION_DAYS=3650
soviez_s5_backup_retention_cleanup "$BACKUP_ROOT"
[[ -d "$keep" ]]
[[ -f "$keep/PRESERVE" ]]
echo "OK retention PRESERVE kept"

# disk_preflight with huge need fails
set +e
disk="$(SOVIEZ_S5_DISK_MARGIN_KB=0 soviez_s5_disk_preflight 999999999999 2>/dev/null)"
disk_rc=$?
set -e
[[ "$disk" == "FAIL" ]]
[[ "$disk_rc" -ne 0 ]]
echo "OK disk_preflight huge need FAIL"

# restore_verify EXTERNAL_UNKNOWN requires S4 (quarantine create or fail closed)
needs="$(soviez_s5_restore_verify_requires_s4 EXTERNAL_UNKNOWN)"
[[ "$needs" == "true" ]]
# With S4 modules sourced, create quarantine path should PASS
rv="$(soviez_s5_restore_verify "$bdir" EXTERNAL_UNKNOWN)"
[[ "$rv" == "PASS" ]]
# Fail closed when S4 helpers unavailable (source restore_verify alone)
set +e
fc="$(
  bash -c '
    set +e
    source "'"$ROOT"'/src/security/backup_safety/restore_verify.sh"
    soviez_s5_restore_verify /tmp EXTERNAL_UNKNOWN 2>/dev/null
  '
)"
set -e
[[ "$fc" == "FAIL" ]]
echo "OK restore_verify requires S4 / fail closed"

# encryption: assert_ciphertext on .enc vs plaintext .sql
encf="$bdir/db.dump.enc"
printf 'Salted__ciphertext-fake-bytes\n' >"$encf"
[[ "$(soviez_s5_backup_assert_ciphertext "$encf")" == "PASS" ]]
plain="$bdir/plain.sql"
printf '%s\n' '-- PostgreSQL database dump' 'CREATE TABLE t(id int);' >"$plain"
set +e
plain_out="$(soviez_s5_backup_assert_ciphertext "$plain" 2>/dev/null)"
plain_rc=$?
set -e
[[ "$plain_out" == "FAIL" ]]
[[ "$plain_rc" -ne 0 ]]
echo "OK encryption ciphertext vs plaintext"

echo PASS
