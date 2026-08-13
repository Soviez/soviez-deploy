#!/usr/bin/env bash
# Phase 16 final — real MinIO S3-compatible multipart backup/download/delete + interrupts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required" >&2; exit 1; }
# Recreate fixture if missing or orphaned after Colima reboot (stale network id).
ensure_minio() {
  docker network create soviez-p16-net >/dev/null 2>&1 || true
  if docker inspect soviez-p16-minio >/dev/null 2>&1; then
    if docker start soviez-p16-minio >/dev/null 2>&1; then
      return 0
    fi
    docker rm -f soviez-p16-minio >/dev/null 2>&1 || true
  fi
  docker run -d --name soviez-p16-minio --network soviez-p16-net \
    -p 19000:9000 -p 19001:9001 \
    -e MINIO_ROOT_USER=soviezminio -e MINIO_ROOT_PASSWORD=soviezminiosecret \
    minio/minio:RELEASE.2024-12-18T13-15-44Z server /data --console-address :9001 >/dev/null
}
ensure_minio
# Wait for MinIO API
for i in $(seq 1 60); do
  if curl -fsS --max-time 2 http://127.0.0.1:19000/minio/health/live >/dev/null 2>&1 \
     || curl -fsS --max-time 2 http://127.0.0.1:19000/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec soviez-p16-minio mc alias set local http://127.0.0.1:9000 soviezminio soviezminiosecret >/dev/null 2>&1 || true
docker exec soviez-p16-minio mc mb -p local/soviez-p16-cert >/dev/null 2>&1 || true
export SOVIEZ_S3_ENDPOINT=http://127.0.0.1:19000 SOVIEZ_S3_BUCKET=soviez-p16-cert
export SOVIEZ_S3_ACCESS_KEY=soviezminio SOVIEZ_S3_SECRET_KEY=soviezminiosecret
export SOVIEZ_S3_REGION=us-east-1 SOVIEZ_S3_PREFIX_OWNER=backups
ok_bucket=0
for i in $(seq 1 30); do
  if soviez_backup_s3_client ensure_bucket >/dev/null 2>&1; then ok_bucket=1; break; fi
  ensure_minio
  docker exec soviez-p16-minio mc mb -p local/soviez-p16-cert >/dev/null 2>&1 || true
  sleep 1
done
[[ "$ok_bucket" -eq 1 ]] || { echo "FAIL: MinIO bucket not ready" >&2; exit 1; }

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_S3_REAL=1
export SOVIEZ_BACKUP_PASSPHRASE="p16-s3-real-passphrase-not-production"
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_ROOT="$ROOT/.tmp/p16-s3-real-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init

HOST="$(hostname -f 2>/dev/null || hostname)"
PROD=prod-s3-real
mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore"
# Larger filestore to force multipart (>=5MiB object after encrypt may still need padding — add big file)
dd if=/dev/urandom of="$SOVIEZ_TENANT_DIR/$PROD/filestore/payload.bin" bs=1024 count=6144 status=none
printf 'db-marker\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic-s3","database_uuid":"11111111-1111-1111-1111-111111111111",
  "database_name":"db_s3_real","host_identity":"$HOST","fingerprint":"fp-$PROD",
  "production_fingerprint":"fp-$PROD","erp_major":"18",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "current_digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
},separators=(",",":")))
PY

soviez_backup_destination_write "$(python3 - <<'PY'
import json
print(json.dumps({
  "profile_id":"minio-real","kind":"s3","endpoint":"http://127.0.0.1:19000",
  "bucket":"soviez-p16-cert","prefix":"backups","region":"us-east-1","path_style":True,
  "tls":"fixture_http_only"
},separators=(",",":")))
PY
)" >/dev/null
soviez_backup_destination_write_secret minio-real '{"access_key":"soviezminio","secret_key":"soviezminiosecret"}'

# Destination test
soviez_backup_destination_test minio-real | grep -q BACKUP_DESTINATION_OK

# Full backup → encrypt → multipart upload
out="$(soviez_backup_run "$PROD" minio-real full 1)"
echo "$out" | grep -q BACKUP_COMPLETED || { echo "backup failed: $out" >&2; exit 1; }
BID="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
OP="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("operation_id",""))')"

# Inventory lists exact backup
idx="$(soviez_backup_inventory_load)"
echo "$idx" | grep -q "$BID"

# Remote objects present (exact prefix)
export SOVIEZ_S3_ENDPOINT=http://127.0.0.1:19000 SOVIEZ_S3_BUCKET=soviez-p16-cert
export SOVIEZ_S3_ACCESS_KEY=soviezminio SOVIEZ_S3_SECRET_KEY=soviezminiosecret
export SOVIEZ_S3_REGION=us-east-1 SOVIEZ_S3_PREFIX_OWNER=backups
export SOVIEZ_S3_PREFIX="backups/${PROD}/${BID}/"
list="$(soviez_backup_s3_client list)"
echo "$list" | grep -q "$BID"
KEYS="$(echo "$list" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["keys"]))')"
[[ -n "$KEYS" ]] || { echo "no remote keys" >&2; exit 1; }

# Download exact objects + checksum
dl="$SOVIEZ_ROOT/s3-download"
profile="$(soviez_backup_destination_resolve minio-real)"
soviez_backup_s3_dest_get "$profile" "$dl" "$BID" "$PROD" >/dev/null
find "$dl" -type f | grep -q .
# Decrypt one enc file if present
enc="$(find "$dl" -name '*.enc' | head -1 || true)"
if [[ -n "$enc" ]]; then
  soviez_backup_decrypt_file "$enc" "$dl/decrypted.bin"
  [[ -s "$dl/decrypted.bin" ]]
fi

# Exact deletion of one object
first="$(echo "$KEYS" | head -1)"
base="$(basename "$first")"
soviez_backup_s3_dest_delete_exact "$profile" "$PROD" "$BID" "$base" | grep -q BACKUP_RETENTION_CLEANUP
export SOVIEZ_S3_KEY="$first"
set +e
soviez_backup_s3_client head >/dev/null 2>&1
hrc=$?
set -e
[[ $hrc -ne 0 ]] || { echo "object still present after exact delete" >&2; exit 1; }

# --- Interruption matrix (multipart) ---
big="$SOVIEZ_ROOT/interrupt.bin"
dd if=/dev/zero of="$big" bs=1024 count=6144 status=none
export SOVIEZ_S3_LOCAL="$big" SOVIEZ_S3_KEY="backups/${PROD}/irq/payload.bin"
export SOVIEZ_S3_STATE_FILE="$SOVIEZ_ROOT/irq-mp.json"

for irq in before_first_part middle_part before_complete after_complete_before_local; do
  rm -f "$SOVIEZ_S3_STATE_FILE"
  export SOVIEZ_BACKUP_S3_INTERRUPT="$irq"
  set +e
  outirq="$(soviez_backup_s3_client multipart_put 2>&1)"
  irc=$?
  set -e
  [[ $irc -ne 0 ]] || { echo "interrupt $irq did not fail" >&2; exit 1; }
  echo "$outirq" | grep -q BACKUP_TRANSFER_INTERRUPTED
done
unset SOVIEZ_BACKUP_S3_INTERRUPT

# Resume after middle_part interrupt
rm -f "$SOVIEZ_S3_STATE_FILE"
export SOVIEZ_BACKUP_S3_INTERRUPT=middle_part
set +e
soviez_backup_s3_client multipart_put >/dev/null 2>&1
set -e
unset SOVIEZ_BACKUP_S3_INTERRUPT
# Resume should complete using saved upload_id/parts
soviez_backup_s3_client multipart_put | grep -q S3_PUT
soviez_backup_s3_client head | grep -q S3_HEAD_OK
# Idempotent finalization
soviez_backup_s3_client multipart_put | grep -q S3_PUT
soviez_backup_s3_client delete | grep -q S3_DELETE_OK

# Download / verify / delete interrupts
export SOVIEZ_S3_KEY="backups/${PROD}/irq2/x.bin" SOVIEZ_S3_LOCAL="$big" SOVIEZ_S3_STATE_FILE="$SOVIEZ_ROOT/irq2.json"
soviez_backup_s3_client multipart_put >/dev/null
export SOVIEZ_BACKUP_S3_INTERRUPT=during_download SOVIEZ_S3_LOCAL="$SOVIEZ_ROOT/x.down"
set +e; soviez_backup_s3_client get >/dev/null 2>&1; set -e
unset SOVIEZ_BACKUP_S3_INTERRUPT
export SOVIEZ_BACKUP_S3_INTERRUPT=during_verify
set +e; soviez_backup_s3_client head >/dev/null 2>&1; set -e
unset SOVIEZ_BACKUP_S3_INTERRUPT
export SOVIEZ_BACKUP_S3_INTERRUPT=during_delete
set +e; soviez_backup_s3_client delete >/dev/null 2>&1; set -e
unset SOVIEZ_BACKUP_S3_INTERRUPT
soviez_backup_s3_client delete >/dev/null

# --- Failure injection ---
fail_probe() {
  local label="$1"; shift
  set +e
  "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  [[ $rc -ne 0 ]] || { echo "expected failure: $label" >&2; exit 1; }
}
export SOVIEZ_S3_ACCESS_KEY=wrong
fail_probe wrong_access soviez_backup_s3_client ensure_bucket
export SOVIEZ_S3_ACCESS_KEY=soviezminio SOVIEZ_S3_SECRET_KEY=wrong
fail_probe wrong_secret soviez_backup_s3_client ensure_bucket
export SOVIEZ_S3_SECRET_KEY=soviezminiosecret SOVIEZ_S3_ENDPOINT=http://127.0.0.1:19999
fail_probe unavailable_endpoint soviez_backup_s3_client ensure_bucket
export SOVIEZ_S3_ENDPOINT=http://127.0.0.1:19000 SOVIEZ_S3_BUCKET=missing-bucket-xyz
fail_probe bucket_missing soviez_backup_s3_client ensure_bucket
export SOVIEZ_S3_BUCKET=soviez-p16-cert SOVIEZ_S3_PREFIX_OWNER=other-prefix
export SOVIEZ_S3_KEY=backups/x/y/z.bin
fail_probe prefix_mismatch soviez_backup_s3_client head

# Secret redaction: ensure secret key not in op state / inventory
if grep -R "soviezminiosecret" "$SOVIEZ_BACKUP_OPS_DIR" "$SOVIEZ_BACKUP_INVENTORY_DIR" 2>/dev/null; then
  echo "secret leaked into state/inventory" >&2; exit 1
fi
# argv scan of current process tree for secret (best-effort)
if ps eww -a 2>/dev/null | grep -F soviezminiosecret | grep -v grep; then
  echo "secret visible in process listing" >&2; exit 1
fi || true

# Static gate: no recursive s3 rm in source
! grep -E 'aws s3 rm --recursive|mc rm --recursive|rclone purge' "$ROOT/src/backup/s3_destination.sh"

echo "PASS test_backup_s3_real"
rm -rf "$SOVIEZ_ROOT"
