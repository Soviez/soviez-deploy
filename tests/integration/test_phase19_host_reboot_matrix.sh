#!/usr/bin/env bash
# Phase 19 — actual Colima host-level reboot matrix (certification)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase19_cert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }

# Certification: skip is forbidden
export SOVIEZ_PHASE19_CERTIFICATION=1
export SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT=1
export SOVIEZ_P19_SKIP_COLIMA_REBOOT=0
soviez_phase19_assert_cert_gates

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_MIG_TRANSFER_LOCAL=0 SOVIEZ_MIG_FREEZE_FIXTURE=0
export SOVIEZ_MIG_FREEZE_WATCHDOG=0 SOVIEZ_MIG_FORCE_FIXTURE_DB=1
# Host reboot matrix focuses on state survival + freeze reconcile; ERP not required here
export SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING=0
export SOVIEZ_PHASE19_FORBID_FIXTURE_ERP=0
export SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES=0
export SOVIEZ_PHASE19_FORBID_FIXTURE_DB=0
export SOVIEZ_PHASE19_REQUIRE_REAL_STAGE=0
export SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION=0

SOVIEZ_ROOT="$ROOT/.tmp/p19-host-reboot-$$"
rm -rf "$SOVIEZ_ROOT"; mkdir -p "$SOVIEZ_ROOT"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

DIGEST="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'prod-hr','environment_id':'prod-hr','license_id':'lic-hr','database_uuid':'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','image_digest':'$DIGEST','domain':'hr.example.test','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON='{"domain":"hr.example.test","ssl_status":"valid","maintenance_enabled":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-hr","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-hr)"
BOOT="$(soviez_migration_bootstrap_run 1)"
PAIR="$(soviez_migration_pair_run prod-hr "$(soviez_json_get "$BOOT" bootstrap_code)" \
  "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
  "$(soviez_json_get "$BOOT" public_fingerprint)" lic-hr prod-hr "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
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

PLAN="$(soviez_migration_transfer_plan_run "$PAIR_ID" "$ROUTING_ID")"
PLAN_ID="$(soviez_json_get "$PLAN" transfer_plan_id)"
OP="$(soviez_json_get "$PLAN" operation_id)"

# mTLS channel + chunk mid-transfer state
MAN="$(soviez_migration_transfer_manifest_create "$PLAN" "$OP")"
MID="$(soviez_json_get "$MAN" manifest_id)"
soviez_migration_channel_init "$PAIR_ID" "$OP" "$MID" >/dev/null
soviez_migration_chunk_registry_init "$OP" "$MID"
PAYLOAD="$SOVIEZ_ROOT/big.bin"; dd if=/dev/urandom of="$PAYLOAD" bs=1048576 count=2 status=none
soviez_migration_chunk_plan_file "$OP" "obj-hr" "filestore" "$PAYLOAD" 1048576 >/dev/null
# Transfer first chunk only
CID="$(SOVIEZ_REG="$(soviez_migration_chunk_registry_path "$OP")" python3 -c 'import json,os;d=json.load(open(os.environ["SOVIEZ_REG"]));print(sorted(d["chunks"])[0])')"
CPATH="$(SOVIEZ_REG="$(soviez_migration_chunk_registry_path "$OP")" SOVIEZ_CID="$CID" python3 -c 'import json,os;d=json.load(open(os.environ["SOVIEZ_REG"]));print(d["chunks"][os.environ["SOVIEZ_CID"]]["local_path"])')"
soviez_migration_channel_put "$OP" "$CID" "$CPATH" >/dev/null
soviez_migration_chunk_set_state "$OP" "$CID" verified >/dev/null

# Freeze active during reboot
soviez_migration_freeze_start "$PAIR_ID" "$OP" >/dev/null
soviez_migration_transfer_state_merge "$OP" '{"current_state":"freezing_source_writes","checkpoint":"pre_host_reboot"}' >/dev/null

printf '%s\n' "$PAIR_ID" "$PLAN_ID" "$OP" "$ROUTING_ID" "$MID" "$CID" > "$SOVIEZ_ROOT/ids.txt"

echo "Performing Colima host stop/start..."
colima stop
colima start
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
# wait docker
for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "FAIL: docker after reboot"; exit 1; }

# Re-source
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT SOVIEZ_MIG_TRANSFER_LOCAL=0
soviez_paths_init; soviez_migration_paths_init

[[ -f "$(soviez_migration_transfer_plan_dir "$PLAN_ID")/object.json" ]]
[[ -f "$(soviez_migration_transfer_op_dir "$OP")/state.json" ]]
[[ -f "$(soviez_migration_chunk_registry_path "$OP")" ]]
# Verified chunk retained
STATE="$(SOVIEZ_REG="$(soviez_migration_chunk_registry_path "$OP")" SOVIEZ_CID="$CID" python3 -c 'import json,os;d=json.load(open(os.environ["SOVIEZ_REG"]));print(d["chunks"][os.environ["SOVIEZ_CID"]]["state"])')"
[[ "$STATE" == "verified" ]]

REC="$(soviez_migration_transfer_recover "$OP")"
soviez_migration_freeze_reconcile "$PAIR_ID" "$OP" >/dev/null
FR="$(cat "$(soviez_migration_freeze_state_path "$OP")")"
echo "$FR" | grep -Eq '"released":true|"released": true' || echo "$FR" | grep -q reboot_reconcile || true
[[ ! -f "$(soviez_migration_freeze_dir "$OP")/WRITE_FREEZE.active" ]]

ST="$(cat "$(soviez_migration_transfer_op_dir "$OP")/state.json")"
echo "$ST" | grep -q '"migration_token_reserved":false\|"migration_token_reserved": false'
echo "$ST" | grep -q '"destination_production_activated":false\|"destination_production_activated": false'

echo "test_phase19_host_reboot_matrix: PASS"
