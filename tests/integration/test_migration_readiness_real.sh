#!/usr/bin/env bash
# Phase 17 final — readiness PASS/WARNING/BLOCKED + signature + invalidation
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-ready.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=5000000
DIGEST="sha256:$(printf ready | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-rdy","environment_id":"prod-rdy","license_id":"lic-rdy","database_uuid":"55555555-5555-5555-5555-555555555555","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON="$(python3 -c 'import json; print(json.dumps({"stages":[{"stage_id":"st-ok","parent_production_id":"prod-rdy","status":"active","retention_deadline":"2099-01-01","database_bytes":1,"filestore_bytes":1,"owner_selected":False,"selectable":True,"selectable_reason":"ok"},{"stage_id":"st-exp","parent_production_id":"prod-rdy","status":"expired","retention_deadline":"2020-01-01","database_bytes":1,"filestore_bytes":1,"owner_selected":False,"selectable":False,"selectable_reason":"expired"}]}))')"
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

pair_flow() {
  local disc boot code bid src dst lic pair
  disc="$(soviez_migration_discover_run prod-rdy)"
  boot="$(soviez_migration_bootstrap_run 1)"
  code="$(soviez_json_get "$boot" bootstrap_code)"; bid="$(soviez_json_get "$boot" bootstrap_id)"
  src="$(soviez_json_get "$disc" identity.host_identity.fingerprint)"
  dst="$(soviez_json_get "$boot" public_fingerprint)"
  lic="$(soviez_json_get "$disc" identity.license_id)"
  pair="$(soviez_migration_pair_run prod-rdy "$code" "$src" "$dst" "$lic" prod-rdy "$bid" 1)"
  printf '%s\n' "$(soviez_json_get "$pair" migration_pair_id)"
}

PID="$(pair_flow)"
R="$(soviez_migration_readiness_run "$PID")"
[[ "$(soviez_json_get "$R" result)" == "PASS" ]]
[[ "$(soviez_json_get "$R" capacity_matrix.margin_pct)" == "25" ]]
RID="$(soviez_json_get "$R" report_id)"
soviez_migration_readiness_show "$RID" >/dev/null
[[ "$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID")/object.json")" selected_stage_ids)" == "[]" ]]
soviez_migration_stage_select "$PID" st-ok select >/dev/null
( soviez_migration_stage_select "$PID" st-exp select ) 2>/dev/null && exit 1 || true

# Invalidation: mutate discovery image digest after report
DID="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID")/object.json")" source_discovery_id)"
DP="$(soviez_migration_discovery_dir "$DID")/object.json"
python3 - <<PY
import json
p="$DP"
d=json.load(open(p))
d["identity"]["image_digest"]="sha256:changedchangedchangedchangedchangedchangedchangedchanged"
open(p,"w").write(json.dumps(d, separators=(",",":")))
PY
soviez_migration_sign_object_file "$DP"
( soviez_migration_readiness_show "$RID" ) 2>/dev/null && { echo "FAIL invalidation"; exit 1; } || true

# WARNING old backup
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"verified_old","capability_healthy":true,"latest_verified_age_seconds":200000,"restore_tested":false}'
PID2="$(pair_flow)"
R2="$(soviez_migration_readiness_run "$PID2")"
[[ "$(soviez_json_get "$R2" result)" == "WARNING" ]]

# BLOCKED capacity
PID3="$(pair_flow)"
BID3="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID3")/object.json")" destination_bootstrap_id)"
BP="$(soviez_migration_bootstrap_dir "$BID3")/object.json"
python3 - <<PY
import json
p="$BP"
d=json.load(open(p))
d["preflight"]["available_bytes"]=100
open(p,"w").write(json.dumps(d, separators=(",",":")))
PY
soviez_migration_sign_object_file "$BP"
R3="$(soviez_migration_readiness_run "$PID3")"
[[ "$(soviez_json_get "$R3" result)" == "BLOCKED" ]]

# Clock skew
( soviez_migration_assert_clock_skew $(( $(date -u +%s) + 10000 )) ) 2>/dev/null && exit 1 || true

echo "test_migration_readiness_real: PASS"
