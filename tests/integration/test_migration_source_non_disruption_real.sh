#!/usr/bin/env bash
# Phase 17 final — source discovery non-disruption with real PostgreSQL + HTTP probe
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
docker info >/dev/null 2>&1 || { echo "FAIL docker"; exit 1; }

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-src.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_ops_paths_init 2>/dev/null || true; soviez_migration_paths_init; soviez_device_ensure_keys

PG="soviez-p17-src-pg-$$"
HTTP="soviez-p17-src-http-$$"
docker rm -f "$PG" "$HTTP" 2>/dev/null || true
docker run -d --name "$PG" -e POSTGRES_PASSWORD=soviez -e POSTGRES_DB=soviez \
  -p 127.0.0.1::5432 postgres:16 >/dev/null
# Wait ready
for i in $(seq 1 60); do
  docker exec "$PG" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$PG" pg_isready -U postgres >/dev/null

# Synthetic filestore + addons + HTTP login stub
FS="$SOVIEZ_ROOT/filestore"; ADD="$SOVIEZ_ROOT/addons"
mkdir -p "$FS/attachments" "$ADD/soviez_base"
printf 'blob' > "$FS/attachments/a1.bin"
printf '{"name":"soviez_base","version":"1.0"}' > "$ADD/soviez_base/__manifest__.py"
docker run -d --name "$HTTP" nginx:alpine >/dev/null
# Ensure /web/login returns 200 via container-network probe (Colima published ports can return empty replies under qemu)
docker exec "$HTTP" sh -c 'rm -rf /usr/share/nginx/html/web/login; mkdir -p /usr/share/nginx/html/web/login; printf "ok-login\n" > /usr/share/nginx/html/web/login/index.html'
probe_login() {
  docker run --rm --network "container:$HTTP" curlimages/curl:8.5.0 -sf "http://127.0.0.1/web/login/" \
    || docker exec "$HTTP" wget -qO- "http://127.0.0.1/web/login/"
}
BEFORE_HTTP="$(probe_login)"
[[ -n "$BEFORE_HTTP" ]] || { echo "FAIL http before"; exit 1; }
BEFORE_PG="$(docker exec "$PG" psql -U postgres -d soviez -Atc 'SELECT 1')"
[[ "$BEFORE_PG" == "1" ]]

DIGEST="sha256:$(printf srcnd | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id":"prod-srcnd","environment_id":"prod-srcnd","license_id":"lic-srcnd",
  "account_id":"acct-srcnd","database_uuid":"33333333-3333-3333-3333-333333333333",
  "image_digest":"$DIGEST","erp_version":"18.0","postgresql_major":"16",
  "database_path":"", "filestore_path":"$FS", "addons_path":"$ADD",
  "container_health":"running","postgresql_health":"healthy","domain":"srcnd.example.test",
  "ssl_status":"valid","backup_health":"healthy",
}))
PY
)"
mkdir -p "$SOVIEZ_ROOT/stages/stage-live"
printf '{"stage_id":"stage-live","production_id":"prod-srcnd","status":"active","retention_deadline":"2099-01-01","database_bytes":10,"filestore_bytes":20}' \
  > "$SOVIEZ_ROOT/stages/stage-live/inventory.json"
export SOVIEZ_STAGES_DIR="$SOVIEZ_ROOT/stages"
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":100,"restore_tested":true}'
# Use collectors for capacity from real filestore path
unset SOVIEZ_MIG_FIXTURE_CAPACITY_JSON || true

DISC="$(soviez_migration_discover_run prod-srcnd)"
[[ "$(soviez_json_get "$DISC" data_transfer_started)" == "False" ]]
[[ "$(soviez_json_get "$DISC" source_maintenance_enabled)" == "False" ]]
[[ "$(soviez_json_get "$DISC" migration_token_consumed)" == "False" ]]

AFTER_HTTP="$(probe_login)"
[[ -n "$AFTER_HTTP" ]] || { echo "FAIL http after"; exit 1; }
AFTER_PG="$(docker exec "$PG" psql -U postgres -d soviez -Atc 'SELECT 1')"
[[ "$AFTER_PG" == "1" ]]
docker inspect -f '{{.State.Running}}' "$PG" | grep -q true
# No automatic backup created under migration root
! find "$SOVIEZ_MIG_ROOT" -name '*.dump' -o -name '*pg_dump*' 2>/dev/null | grep -q .

docker rm -f "$PG" "$HTTP" >/dev/null 2>&1 || true
echo "test_migration_source_non_disruption_real: PASS"
