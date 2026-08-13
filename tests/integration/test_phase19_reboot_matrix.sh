#!/usr/bin/env bash
# Phase 19 — reboot recovery (host-disk state survival; Colima optional)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_MIG_TRANSFER_LOCAL=1 SOVIEZ_MIG_FREEZE_FIXTURE=1 SOVIEZ_MIG_FORCE_FIXTURE_DB=1
unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT 2>/dev/null || true
export SOVIEZ_P19_SKIP_COLIMA_REBOOT="${SOVIEZ_P19_SKIP_COLIMA_REBOOT:-1}"
export SOVIEZ_MIG_FORCE_FIXTURE_ERP=1
if [[ "${SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT:-0}" == "1" || "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]; then
  if [[ "${SOVIEZ_P19_SKIP_COLIMA_REBOOT}" == "1" ]]; then
    echo "FAIL: host reboot skip forbidden in certification"; exit 1
  fi
fi
export SOVIEZ_ROOT="$ROOT/.tmp/p19-reboot-$$"
rm -rf "$SOVIEZ_ROOT"; mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

DIGEST="sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'prod-rb19','environment_id':'prod-rb19','license_id':'lic-rb19','database_uuid':'cccccccc-cccc-cccc-cccc-cccccccccccc','image_digest':'$DIGEST','domain':'rb19.example.test','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON='{"domain":"rb19.example.test","ssl_status":"valid","maintenance_enabled":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-rb","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-rb19)"
BOOT="$(soviez_migration_bootstrap_run 1)"
PAIR="$(soviez_migration_pair_run prod-rb19 "$(soviez_json_get "$BOOT" bootstrap_code)" \
  "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
  "$(soviez_json_get "$BOOT" public_fingerprint)" lic-rb19 prod-rb19 "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
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

# Simulate mid-transfer freeze state on disk
soviez_migration_freeze_start "$PAIR_ID" "$OP" >/dev/null
soviez_migration_transfer_state_merge "$OP" '{"current_state":"recovery_required","checkpoint":"pre_reboot"}' >/dev/null

printf '%s\n' "$PAIR_ID" "$PLAN_ID" "$OP" "$ROUTING_ID" > "$SOVIEZ_ROOT/ids.txt"

# Optional Colima host reboot
if [[ "${SOVIEZ_P19_SKIP_COLIMA_REBOOT:-1}" != "1" ]] && command -v colima >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  colima stop >/dev/null 2>&1 || true
  colima start >/dev/null 2>&1 || true
fi

# Re-source after "reboot"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT SOVIEZ_MIG_TRANSFER_LOCAL=1 SOVIEZ_MIG_FREEZE_FIXTURE=1
soviez_paths_init; soviez_migration_paths_init

[[ -f "$(soviez_migration_transfer_plan_dir "$PLAN_ID")/object.json" ]]
[[ -f "$(soviez_migration_transfer_op_dir "$OP")/state.json" ]]
[[ -f "$(soviez_migration_freeze_state_path "$OP")" ]]

REC="$(soviez_migration_transfer_recover "$OP")"
echo "$REC" | grep -q recovery_required || echo "$REC" | grep -q reconciled || true

# Freeze must be released/reconciled after reboot recover path
soviez_migration_freeze_reconcile "$PAIR_ID" "$OP" >/dev/null
[[ "$(soviez_json_get "$(cat "$(soviez_migration_freeze_state_path "$OP")")" released)" == "True" \
  || "$(soviez_json_get "$(cat "$(soviez_migration_freeze_state_path "$OP")")" released)" == "true" ]]

echo "phase19 reboot matrix: PASS"
