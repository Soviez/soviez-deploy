#!/usr/bin/env bash
# Phase 16 — Stage live PostgreSQL backup reconfirm (shared primitives).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required" >&2; exit 1; }

export SOVIEZ_TEST_MODE=1
export SOVIEZ_STAGE_USE_LIVE_PG=1
export SOVIEZ_PG_CONTAINER=soviez-p16-stage-pg
export SOVIEZ_PG_USER=odoo
export SOVIEZ_PG_PASSWORD=odoo
export PGPASSWORD=odoo
export SOVIEZ_ROOT="$ROOT/.tmp/p16-stage-live-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_stage_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init

# Disposable PG
docker rm -f "$SOVIEZ_PG_CONTAINER" 2>/dev/null || true
docker run -d --name "$SOVIEZ_PG_CONTAINER" \
  -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 60); do
  docker exec "$SOVIEZ_PG_CONTAINER" pg_isready -U odoo >/dev/null 2>&1 && break
  sleep 1
done

STAGE=stage-live-p16
DB=db_stage_live_p16
docker exec "$SOVIEZ_PG_CONTAINER" psql -U odoo -d postgres -c "CREATE DATABASE \"$DB\" OWNER odoo;" >/dev/null
docker exec "$SOVIEZ_PG_CONTAINER" psql -U odoo -d "$DB" -c "CREATE TABLE t(id int); INSERT INTO t VALUES (42);" >/dev/null

mkdir -p "$SOVIEZ_STAGES_DIR/$STAGE/filestore" "$SOVIEZ_STAGES_DIR/$STAGE/db"
printf 'stage-fs\n' > "$SOVIEZ_STAGES_DIR/$STAGE/filestore/x"
python3 - <<PY > "$SOVIEZ_STAGES_DIR/$STAGE/identity.json"
import json
print(json.dumps({
  "stage_id":"$STAGE","parent_production_tenant_id":"prod-parent-p16",
  "database_name":"$DB","db_name":"$DB","stage_db_name":"$DB",
  "filestore_path":"$SOVIEZ_STAGES_DIR/$STAGE/filestore",
  "stage_filestore_path":"$SOVIEZ_STAGES_DIR/$STAGE/filestore",
  "status":"ready",
},separators=(",",":")))
PY

# Live backup via shared primitive
out="$(soviez_backup_stage_live_backup "$STAGE" 2>&1)"
echo "$out" | grep -q 'Backup written:' || { echo "stage live backup unexpected: $out" >&2; exit 1; }
archive="$(echo "$out" | awk -F': ' '/Backup written:/{print $2; exit}')"
[[ -n "$archive" && -f "$archive" ]] || { echo "missing stage archive" >&2; exit 1; }
# Extract dump from archive and verify real PG custom-format magic
tmpdir="$(mktemp -d)"
tar -C "$tmpdir" -xf "$archive"
dump="$(find "$tmpdir" -name 'db.dump' | head -1)"
[[ -n "$dump" && -s "$dump" ]] || { echo "missing live dump artifact in archive" >&2; exit 1; }
python3 - <<PY
p="$dump"
raw=open(p,"rb").read(5)
assert raw.startswith(b"PGDMP"), raw[:20]
print("pgdump_magic_ok")
PY
rm -rf "$tmpdir"

# Not classified as Production inventory backup
idx="$(soviez_backup_inventory_load 2>/dev/null || echo '{}')"
echo "$idx" | python3 -c 'import json,sys; d=json.load(sys.stdin); 
backs=d.get("backups") or []
bad=[b for b in backs if b.get("production_id")=="'"$STAGE"'"]
assert not bad, bad
print("no_stage_as_production")'

# Production backup still refused for stage id
set +e
bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_ASSUME_YES=1
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_run "'"$STAGE"'" local-primary full 1
' >/dev/null 2>&1
prc=$?
set -e
[[ $prc -ne 0 ]] || { echo "stage must not accept production backup" >&2; exit 1; }

docker rm -f "$SOVIEZ_PG_CONTAINER" >/dev/null 2>&1 || true
echo "PASS test_stage_backup_live_db"
rm -rf "$SOVIEZ_ROOT"
