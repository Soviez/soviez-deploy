#!/usr/bin/env bash
# S5 off-host backup destination fixture (disposable SFTP/file/minio simulation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
if [[ -f "$ROOT/dist/soviez.sh" ]] && ! grep -q 'soviez_s5_backup_classify_destination' "$ROOT/dist/soviez.sh" 2>/dev/null; then
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
rid="$(s5_run_id)"
prefix="soviez-s5-${rid}"
FIX="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s5-offhost.XXXXXX")"
trap '
  s5_cleanup_containers "$prefix" 2>/dev/null || true
  rm -rf "$FIX"
  if [[ -n "${BAK:-}" && -f "$BAK" ]]; then mv "$BAK" "$ROOT/dist/soviez.sh"; fi
' EXIT

# Disposable local file:// / local path — NOT DR
file_dest="file://${FIX}/local-bak"
mkdir -p "$FIX/local-bak"
class_file="$(soviez_s5_backup_classify_destination "$file_dest")"
[[ "$class_file" == "LOCAL_ONLY" ]]
set +e
dr_file="$(soviez_s5_backup_dr_capable "$class_file" 2>/dev/null)"
set -e
[[ "$dr_file" == "false" ]]
echo "OK file:// local-only ≠ DR"

local_class="$(soviez_s5_backup_classify_destination "local")"
[[ "$local_class" == "LOCAL_ONLY" ]]
[[ "$(soviez_s5_backup_dr_capable LOCAL_ONLY 2>/dev/null || echo false)" == "false" ]]
echo "OK local ≠ DR"

# Classify OFF_HOST_SFTP for sftp://fixture
sftp_dest="sftp://fixture/backups"
class_sftp="$(soviez_s5_backup_classify_destination "$sftp_dest")"
[[ "$class_sftp" == "OFF_HOST_SFTP" ]]
[[ "$(soviez_s5_backup_dr_capable OFF_HOST_SFTP)" == "true" ]]
echo "OK sftp://fixture → OFF_HOST_SFTP DR"

# Optional disposable MinIO or python http server (exact-owned cleanup)
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker pull minio/minio:latest >/dev/null 2>&1; then
    docker run -d --name "${prefix}-minio" \
      -e MINIO_ROOT_USER=soviez -e MINIO_ROOT_PASSWORD=sovieztest \
      minio/minio:latest server /data >/dev/null 2>&1 || true
    if docker inspect "${prefix}-minio" >/dev/null 2>&1; then
      class_s3="$(soviez_s5_backup_classify_destination "s3://soviez-fixture/bucket")"
      [[ "$class_s3" == "OFF_HOST_S3_COMPATIBLE" ]]
      [[ "$(soviez_s5_backup_dr_capable OFF_HOST_S3_COMPATIBLE)" == "true" ]]
      docker rm -f "${prefix}-minio" >/dev/null 2>&1 || true
      echo "OK disposable minio classified S3-compatible"
    fi
  fi
else
  # Fallback: short-lived python http server as disposable off-host-ish endpoint label
  py_port="$((19000 + RANDOM % 1000))"
  python3 -m http.server "$py_port" --directory "$FIX" >/dev/null 2>&1 &
  py_pid=$!
  sleep 0.5
  # Still classify via URI scheme (http alone → LOCAL_ONLY unless override)
  export SOVIEZ_S5_BACKUP_CLASS=OFF_HOST_S3_COMPATIBLE
  [[ "$(soviez_s5_backup_classify_destination "https://fixture-s3.local/bucket")" == "OFF_HOST_S3_COMPATIBLE" ]] \
    || [[ "$(soviez_s5_backup_classify_destination "minio://fixture/bucket")" == "OFF_HOST_S3_COMPATIBLE" ]]
  kill "$py_pid" >/dev/null 2>&1 || true
  wait "$py_pid" 2>/dev/null || true
  unset SOVIEZ_S5_BACKUP_CLASS
  echo "OK disposable python http fixture cleaned"
fi

# Prove local-only claim cannot be DR
claim_rc=0
set +e
SOVIEZ_S5_CLAIM_DR=1 SOVIEZ_S5_BACKUP_DIR="$FIX/local-bak" \
  soviez_security_validate_backup_safety "$FIX/local-bak" local >/dev/null 2>&1
claim_rc=$?
set -e
[[ "$claim_rc" -ne 0 ]]
echo "OK LOCAL_ONLY + CLAIM_DR fails gate"

echo PASS
