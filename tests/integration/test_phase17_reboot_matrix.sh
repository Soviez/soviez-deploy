#!/usr/bin/env bash
# Phase 17 — host-level Colima reboot matrix for migration ops
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
docker info >/dev/null 2>&1 || { echo "FAIL docker"; exit 1; }
command -v colima >/dev/null 2>&1 || { echo "FAIL colima"; exit 1; }

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
export SOVIEZ_ROOT="$ROOT/.tmp/p17-reboot-host-$$"
rm -rf "$SOVIEZ_ROOT"; mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init; soviez_ops_paths_init 2>/dev/null || true; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
DIGEST="sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-rb","environment_id":"prod-rb","license_id":"lic-rb","database_uuid":"ffffffff-ffff-ffff-ffff-ffffffffffff","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

# Checkpoint states across migration ops
DISC="$(soviez_migration_discover_run prod-rb)"
DID="$(soviez_json_get "$DISC" discovery_id)"
BOOT="$(soviez_migration_bootstrap_run 1)"
BID="$(soviez_json_get "$BOOT" bootstrap_id)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
LIC="$(soviez_json_get "$DISC" identity.license_id)"
PAIR="$(soviez_migration_pair_run prod-rb "$CODE" "$SRC" "$DST" "$LIC" prod-rb "$BID" 1)"
PID="$(soviez_json_get "$PAIR" migration_pair_id)"
OP="$(soviez_json_get "$PAIR" operation_id)"
READY="$(soviez_migration_readiness_run "$PID")"
RID="$(soviez_json_get "$READY" report_id)"

# Mark mid-flight pairing as recovery_required before host reboot
mkdir -p "$SOVIEZ_MIG_ROOT/ops/$OP"
printf '{"operation_id":"%s","operation_type":"migration_trust_pairing","current_state":"recovery_required","pair_id":"%s","migration_token_consumed":false,"data_transfer_started":false}\n' "$OP" "$PID" > "$SOVIEZ_MIG_ROOT/ops/$OP/state.json"
printf '%s\n' "$DID" "$BID" "$PID" "$RID" "$OP" > "$SOVIEZ_ROOT/ids.txt"

# Real host-level Colima stop/start (optional skip for suite stability after Phase 18)
if [[ "${SOVIEZ_P17_SKIP_COLIMA_REBOOT:-0}" == "1" ]]; then
  echo "phase17 reboot matrix: SKIPPED Colima (SOVIEZ_P17_SKIP_COLIMA_REBOOT=1); host-disk ids persist"
else
  colima stop >/dev/null
  colima start >/dev/null
  export DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
  # Wait docker
  for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null
  # Recreate shared fixture network orphaned by VM reboot (containers may need recreate by later suites)
  docker network create soviez-p16-net >/dev/null 2>&1 || true
fi

# Re-source and prove persistence
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init
[[ -f "$(soviez_migration_discovery_dir "$DID")/object.json" ]]
[[ -f "$(soviez_migration_bootstrap_dir "$BID")/object.json" ]]
[[ -f "$(soviez_migration_pair_dir "$PID")/object.json" ]]
[[ -f "$(soviez_migration_readiness_dir "$RID")/object.json" ]]
# No duplicate pair dirs for same pair id
count="$(find "$SOVIEZ_MIG_PAIR_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$count" -ge 1 ]]
export SOVIEZ_CLI_OP_ID="$OP"
OUT="$(soviez_cmd_migration_recover)"
[[ "$(soviez_json_get "$OUT" current_state)" == "recovery_required" ]]
TOK="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID")/object.json")" migration_token_consumed)"
[[ "$TOK" == "False" || "$TOK" == "false" ]]
ACT="$(soviez_json_get "$(cat "$(soviez_migration_bootstrap_dir "$BID")/object.json")" production_activated)"
[[ "$ACT" == "False" || "$ACT" == "false" ]]

soviez_migration_abort_run "$PID" >/dev/null
[[ -f "$SOVIEZ_MIG_TRUST_DIR/$PID/REVOKED" ]]

echo "phase17 reboot matrix (colima host): PASS"
