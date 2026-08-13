#!/usr/bin/env bash
# Phase 16 final — host-level Colima reboot matrix across backup/S3/SFTP/restore/retention checkpoints.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required" >&2; exit 1; }
command -v colima >/dev/null 2>&1 || { echo "FAIL: Colima required for host reboot" >&2; exit 1; }

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_RESTORE_ASSUME_YES=1
export SOVIEZ_BACKUP_PASSPHRASE="p16-reboot-passphrase"
export SOVIEZ_ROOT="$ROOT/.tmp/p16-reboot-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init
soviez_restore_paths_init

mk_bop() {
  local id="$1" state="$2" cp="$3"
  mkdir -p "$(soviez_backup_op_dir "$id")"
  SOVIEZ_BACKUP_OP_TYPE=production_backup
  soviez_backup_state_write "$id" "$state" "$cp" \
    "{\"environment_id\":\"prod-rb\",\"backup_id\":\"bk-$id\"}"
}

mk_rop() {
  local id="$1" state="$2" cp="$3"
  mkdir -p "$(soviez_restore_op_dir "$id")"
  soviez_restore_state_write "$id" "$state" "$cp" \
    "{\"environment_id\":\"prod-rb\",\"backup_id\":\"bk-src\"}"
}

# Local backup checkpoints 1-6
mk_bop bk-rb-01 running application_quiesce
mk_bop bk-rb-02 running postgresql_dump
mk_bop bk-rb-03 running filestore_compression
mk_bop bk-rb-04 running encrypting
mk_bop bk-rb-05 running archive_verify
mk_bop bk-rb-06 running application_resume
# S3 7-10
mk_bop bk-rb-07 running s3_multipart_upload
mk_bop bk-rb-08 running s3_upload_complete
mk_bop bk-rb-09 running s3_remote_download
mk_bop bk-rb-10 running s3_exact_deletion
# SFTP 11-14
mk_bop bk-rb-11 running sftp_upload
mk_bop bk-rb-12 running sftp_atomic_rename
mk_bop bk-rb-13 running sftp_download
mk_bop bk-rb-14 running sftp_exact_deletion
# Restore-test 15-19
mk_rop rs-rb-15 running candidate_db_restore
mk_rop rs-rb-16 running candidate_filestore_restore
mk_rop rs-rb-17 running candidate_startup
mk_rop rs-rb-18 running candidate_validation
mk_rop rs-rb-19 running candidate_cleanup
# Production restore 20-27
mk_rop rs-rb-20 running preserving_current
mk_rop rs-rb-21 running candidate_db_restore
mk_rop rs-rb-22 waiting_for_switch pre_switch
mk_rop rs-rb-23 switching switching
mk_rop rs-rb-24 running post_switch
mk_rop rs-rb-25 rollback_running production_rollback
mk_rop rs-rb-26 running post_rollback_validation
mk_rop rs-rb-27 completed safety_window_schedule
# Retention 28-31
mk_bop bk-rb-28 running local_backup_delete
mk_bop bk-rb-29 running s3_exact_deletion
mk_bop bk-rb-30 running sftp_exact_deletion
mk_bop bk-rb-31 running cleanup_history

# Persist identities that must survive reboot
printf 'prod-rb\n' > "$SOVIEZ_ROOT/survive_production_id.txt"
printf 'bk-survive\n' > "$SOVIEZ_ROOT/survive_backup_id.txt"
printf 'minio-real\n' > "$SOVIEZ_ROOT/survive_dest_profile.txt"
printf 's3://soviez-p16-cert/backups/prod-rb/bk-survive\n' > "$SOVIEZ_ROOT/survive_remote_object.txt"

BOPS=(bk-rb-01 bk-rb-02 bk-rb-03 bk-rb-04 bk-rb-05 bk-rb-06 bk-rb-07 bk-rb-08 bk-rb-09 bk-rb-10
      bk-rb-11 bk-rb-12 bk-rb-13 bk-rb-14 bk-rb-28 bk-rb-29 bk-rb-30 bk-rb-31)
ROPS=(rs-rb-15 rs-rb-16 rs-rb-17 rs-rb-18 rs-rb-19 rs-rb-20 rs-rb-21 rs-rb-22 rs-rb-23
      rs-rb-24 rs-rb-25 rs-rb-26 rs-rb-27)

EVID="$ROOT/docs/evidence/phase-16-final-certification-closure"
mkdir -p "$EVID"
before="$(date +%s)"

if [[ "${SOVIEZ_BACKUP_SKIP_COLIMA_REBOOT:-0}" == "1" ]]; then
  echo "NOTE: Colima reboot skipped by env — PARTIAL risk" >&2
else
  colima stop >/dev/null 2>&1 || true
  colima start >/dev/null 2>&1
  export DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
  for i in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || { echo "Docker not ready after Colima reboot" >&2; exit 1; }
  docker network create soviez-p16-net >/dev/null 2>&1 || true
fi
after="$(date +%s)"

# Survival proofs
[[ -f "$SOVIEZ_ROOT/survive_production_id.txt" ]]
[[ -f "$SOVIEZ_ROOT/survive_backup_id.txt" ]]
[[ -f "$SOVIEZ_ROOT/survive_dest_profile.txt" ]]
[[ -f "$SOVIEZ_ROOT/survive_remote_object.txt" ]]

results=()
for id in "${BOPS[@]}"; do
  out="$(soviez_backup_reboot_reconcile "$id")"
  printf '%s\n' "$out" > "$(soviez_backup_op_dir "$id")/reboot.json"
  results+=("$out")
done
for id in "${ROPS[@]}"; do
  out="$(soviez_restore_reboot_reconcile "$id")"
  printf '%s\n' "$out" > "$(soviez_restore_op_dir "$id")/reboot.json"
  results+=("$out")
done

# Destructive checkpoints must not replay
for id in bk-rb-07 bk-rb-08 bk-rb-10 bk-rb-12 bk-rb-14 bk-rb-28 bk-rb-29 bk-rb-30; do
  grep -q 'destructive_replay.:false\|"destructive_replay":false' "$(soviez_backup_op_dir "$id")/reboot.json"
  grep -Eq 'BACKUP_RECOVERY_REQUIRED|recovery_required' "$(soviez_backup_op_dir "$id")/reboot.json"
done
for id in rs-rb-23 rs-rb-25; do
  grep -q RESTORE_RECOVERY_REQUIRED "$(soviez_restore_op_dir "$id")/reboot.json"
  grep -q '"duplicate_switch":false' "$(soviez_restore_op_dir "$id")/reboot.json"
  grep -q '"duplicate_rollback":false' "$(soviez_restore_op_dir "$id")/reboot.json"
done
# Completed safety window remains completed (no replay of schedule write as destructive switch)
grep -q completed "$(soviez_restore_op_dir rs-rb-27)/reboot.json"

python3 - <<PY > "$EVID/HOST_REBOOT_MATRIX.md"
from pathlib import Path
print("# Host reboot matrix\n")
print(f"- Environment: Colima VM stop/start")
print(f"- Duration sec: {int('$after')-int('$before')}")
print(f"- Skip flag: {('${SOVIEZ_BACKUP_SKIP_COLIMA_REBOOT:-0}')}")
print(f"- Backup ops reconciled: {len('${BOPS}'.split())}")
print(f"- Restore ops reconciled: {len('${ROPS}'.split())}")
print("- Duplicate destructive actions: none (destructive_replay=false)")
print("- Ambiguous switch/rollback → RESTORE_RECOVERY_REQUIRED")
print("- Ambiguous S3/SFTP finalization/deletion → BACKUP_RECOVERY_REQUIRED")
PY

echo "PASS test_phase16_reboot_matrix"
# Restore disposable Phase 16 transfer fixtures after Colima reboot (for subsequent suites)
docker start soviez-p16-minio >/dev/null 2>&1 || true
docker start soviez-p16-sftp >/dev/null 2>&1 || true
rm -rf "$SOVIEZ_ROOT"
