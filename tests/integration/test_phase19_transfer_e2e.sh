#!/usr/bin/env bash
# Phase 19 — E2E transfer (local channel; docker postgres if available)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
# Default E2E uses real mTLS (local-copy only via explicit SOVIEZ_MIG_TRANSFER_LOCAL=1)
export SOVIEZ_MIG_TRANSFER_LOCAL="${SOVIEZ_MIG_TRANSFER_LOCAL:-0}"
export SOVIEZ_MIG_FREEZE_FIXTURE=1
# Developer e2e: do not inherit certification gates from prior shells
unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_REAL_MTLS SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES \
  SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING SOVIEZ_PHASE19_REQUIRE_REAL_STAGE \
  SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB \
  SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION \
  SOVIEZ_MIG_REAL_ERP_STAGING SOVIEZ_MIG_FORCE_FIXTURE_ERP 2>/dev/null || true
export SOVIEZ_MIG_FORCE_FIXTURE_ERP=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p19-e2e.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

PROD=prod-p19-e2e; LIC=lic-p19-e2e; DOMAIN=e2e19.example.test
DIGEST=sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'$PROD','environment_id':'$PROD','license_id':'$LIC','database_uuid':'ffffffff-ffff-ffff-ffff-ffffffffffff','image_digest':'$DIGEST','domain':'$DOMAIN','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$DOMAIN\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-e2e","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

# Optional real postgres dump
PG_CID=""
cleanup() {
  [[ -n "$PG_CID" ]] && docker rm -f "$PG_CID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  # Do not use --rm: if initdb fails (disk), --rm deletes the CID before diagnostics.
  PG_CID="$(docker run -d --label soviez.phase23.disposable=1 \
    -e POSTGRES_PASSWORD=soviez -e POSTGRES_DB=soviez_src postgres:16-alpine 2>/dev/null || true)"
  if [[ -n "$PG_CID" ]]; then
    ready=0
    for i in $(seq 1 40); do
      if docker exec "$PG_CID" pg_isready -U postgres >/dev/null 2>&1; then
        ready=1
        break
      fi
      if ! docker inspect -f '{{.State.Running}}' "$PG_CID" 2>/dev/null | grep -q true; then
        echo "[p19-transfer] postgres died during readiness" >&2
        docker logs "$PG_CID" 2>&1 | tail -40 >&2 || true
        break
      fi
      sleep 0.5
    done
    if [[ "$ready" -ne 1 ]]; then
      docker logs "$PG_CID" 2>&1 | tail -40 >&2 || true
      docker rm -f "$PG_CID" >/dev/null 2>&1 || true
      PG_CID=""
    fi
  fi
  # pg_isready alone is insufficient: alpine/postgres may still be finishing
  # initdb / restarting ("FATAL: the database system is shutting down") before
  # POSTGRES_DB accepts queries. Wait until SELECT 1 succeeds.
  if [[ -n "$PG_CID" ]]; then
    db_ready=0
    for i in $(seq 1 60); do
      if docker exec -e PGPASSWORD=soviez "$PG_CID" \
        psql -U postgres -d soviez_src -c 'SELECT 1' >/dev/null 2>&1; then
        db_ready=1
        break
      fi
      if ! docker inspect -f '{{.State.Running}}' "$PG_CID" 2>/dev/null | grep -q true; then
        echo "[p19-transfer] postgres died before soviez_src became usable" >&2
        docker logs "$PG_CID" 2>&1 | tail -40 >&2 || true
        break
      fi
      sleep 0.25
    done
    if [[ "$db_ready" -ne 1 ]]; then
      echo "[p19-transfer] database soviez_src never became usable" >&2
      docker logs "$PG_CID" 2>&1 | tail -40 >&2 || true
      docker rm -f "$PG_CID" >/dev/null 2>&1 || true
      PG_CID=""
    fi
  fi
  if [[ -n "$PG_CID" ]]; then
    docker exec -e PGPASSWORD=soviez "$PG_CID" psql -U postgres -d soviez_src -c "CREATE TABLE t(i int); INSERT INTO t VALUES (1);" >/dev/null
    DUMP="$SOVIEZ_ROOT/real.dump"
    docker exec -e PGPASSWORD=soviez "$PG_CID" pg_dump -Fc -U postgres -d soviez_src > "$DUMP"
    export SOVIEZ_MIG_FIXTURE_DB_DUMP="$DUMP"
    export SOVIEZ_MIG_PG_RESTORE_CID="$PG_CID"
    export SOVIEZ_MIG_PG_PASSWORD=soviez
    echo "using real postgres dump + restore target"
  else
    export SOVIEZ_MIG_FORCE_FIXTURE_DB=1
  fi
else
  export SOVIEZ_MIG_FORCE_FIXTURE_DB=1
fi

DISC="$(soviez_migration_discover_run "$PROD")"
BOOT="$(soviez_migration_bootstrap_run 1)"
PAIR="$(soviez_migration_pair_run "$PROD" "$(soviez_json_get "$BOOT" bootstrap_code)" \
  "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
  "$(soviez_json_get "$BOOT" public_fingerprint)" "$LIC" "$PROD" "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"

ROUTING_ID="$(soviez_migration_new_id rplan)"
mkdir -p "$(soviez_migration_routing_plan_dir "$ROUTING_ID")"
python3 - <<PY
import json, datetime
p="$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"
open(p,"w").write(json.dumps({
  "plan_id":"$ROUTING_ID","migration_pair_id":"$PAIR_ID","result":"PASS",
  "issued_at":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at":(datetime.datetime.utcnow()+datetime.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
PY
soviez_migration_sign_object_file "$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"

# Filestore fixture
FS="$SOVIEZ_ROOT/filestore"; mkdir -p "$FS"; echo hello > "$FS/a.txt"
export SOVIEZ_MIG_FIXTURE_FILESTORE_ROOT="$FS"

OUT="$(soviez_migration_transfer_start "$PAIR_ID" "$ROUTING_ID")"
OP="$(soviez_json_get "$OUT" operation_id)"
STAGING="$(soviez_json_get "$OUT" destination_staging_id)"
[[ "$(soviez_json_get "$OUT" current_state)" == "completed" ]]
[[ "$(soviez_json_get "$OUT" migration_token_consumed)" == "False" || "$(soviez_json_get "$OUT" migration_token_consumed)" == "false" ]]
[[ -d "$(soviez_migration_staging_dir "$STAGING")" ]]
# Internal validate markers
[[ -f "$(soviez_migration_staging_dir "$STAGING")/www/web/login" ]] || \
  [[ -f "$(soviez_migration_staging_dir "$STAGING")/health.marker" ]] || \
  [[ -f "$(soviez_migration_staging_dir "$STAGING")/validate.json" ]]

# Freeze released
FZ="$(soviez_migration_freeze_state_path "$OP")"
[[ -f "$FZ" ]]
[[ "$(soviez_json_get "$(cat "$FZ")" released)" == "True" || "$(soviez_json_get "$(cat "$FZ")" released)" == "true" ]]

# Abort preserves staging
ABORT="$(soviez_migration_transfer_abort "$OP")"
[[ "$(soviez_json_get "$ABORT" source_write_freeze)" == "False" || "$(soviez_json_get "$ABORT" source_write_freeze)" == "false" ]]
[[ -d "$(soviez_migration_staging_dir "$STAGING")" ]]

echo "test_phase19_transfer_e2e: PASS"
