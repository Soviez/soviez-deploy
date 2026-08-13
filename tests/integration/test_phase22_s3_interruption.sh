#!/usr/bin/env bash
# Phase 22 G3 — S3 archive upload/retrieve interruption + resume (real MinIO).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }
soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=0
export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP=0
soviez_phase22_assert_cert_gates

ensure_minio() {
  docker network create soviez-p16-net >/dev/null 2>&1 || true
  if docker inspect soviez-p16-minio >/dev/null 2>&1; then
    docker start soviez-p16-minio >/dev/null 2>&1 && return 0
    docker rm -f soviez-p16-minio >/dev/null 2>&1 || true
  fi
  docker run -d --name soviez-p16-minio --network soviez-p16-net \
    -p 19000:9000 -p 19001:9001 \
    -e MINIO_ROOT_USER=soviezminio -e MINIO_ROOT_PASSWORD=soviezminiosecret \
    minio/minio:RELEASE.2024-12-18T13-15-44Z server /data --console-address :9001 >/dev/null
}
ensure_minio
for i in $(seq 1 60); do
  curl -fsS --max-time 2 http://127.0.0.1:19000/minio/health/live >/dev/null 2>&1 && break
  sleep 1
done
docker exec soviez-p16-minio mc alias set local http://127.0.0.1:9000 soviezminio soviezminiosecret >/dev/null 2>&1 || true
docker exec soviez-p16-minio mc mb -p local/soviez-p16-cert >/dev/null 2>&1 || true
export SOVIEZ_S3_ENDPOINT=http://127.0.0.1:19000 SOVIEZ_S3_BUCKET=soviez-p16-cert
export SOVIEZ_S3_ACCESS_KEY=soviezminio SOVIEZ_S3_SECRET_KEY=soviezminiosecret
export SOVIEZ_S3_REGION=us-east-1 SOVIEZ_S3_PREFIX_OWNER=backups
for i in $(seq 1 30); do
  soviez_backup_s3_client ensure_bucket >/dev/null 2>&1 && break
  sleep 1
done

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
soviez_migration_rollback_window_close "$CUTOVER_OP_ID" >/dev/null

soviez_backup_paths_init
soviez_backup_destination_write "$(python3 - <<'PY'
import json
print(json.dumps({
  "profile_id":"p22-minio","kind":"s3","endpoint":"http://127.0.0.1:19000",
  "bucket":"soviez-p16-cert","prefix":"p22-archives","region":"us-east-1","path_style":True,
  "tls":"fixture_http_only"
},separators=(",",":")))
PY
)" >/dev/null
soviez_backup_destination_write_secret p22-minio '{"access_key":"soviezminio","secret_key":"soviezminiosecret"}'
export SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE=p22-minio
export SOVIEZ_BACKUP_S3_REAL=1

# Build archive locally first without remote (disable profile), then test store separately
unset SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE
archive="$(soviez_migration_source_archive_start "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$archive" operation_id)"
export SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE=p22-minio

# Interrupt S3 upload once (before_first_part works for small archives), then resume
export SOVIEZ_MIG_P22_S3_INTERRUPT=1
export SOVIEZ_BACKUP_S3_INTERRUPT=before_first_part
set +e
out="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: expected S3 interrupt; out=$out"; exit 1; }
echo "$out" | grep -q MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED || {
  echo "FAIL: missing interrupt code; out=$out" >&2; exit 1
}

# Resume without interrupt → stored
unset SOVIEZ_MIG_P22_S3_INTERRUPT SOVIEZ_BACKUP_S3_INTERRUPT
export SOVIEZ_MIG_P22_S3_INTERRUPT=0
receipt="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$receipt" status)" "stored" "s3 stored after resume"
assert_eq "$(soviez_json_get "$receipt" duplicate_upload)" "False" "no duplicate" || \
  [[ "$(soviez_json_get "$receipt" duplicate_upload)" == "false" ]]

# Duplicate call is idempotent
receipt2="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$receipt2" status)" "stored" "idempotent store"

# Retrieve interrupt then resume
export SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT=1
set +e
out="$(soviez_migration_p22_archive_retrieve_remote "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]]
unset SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT
export SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT=0
retr="$(soviez_migration_p22_archive_retrieve_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$retr" status)" "retrieved" "retrieve ok"

# Local authoritative archive intact
[[ -f "$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")/archive_bundle.tar.enc" ]]
[[ -d "$SOVIEZ_ROOT/p22_source" ]]

echo "test_phase22_s3_interruption: PASS"
