#!/usr/bin/env bash
# Phase 19 — multi-tenant isolation for transfer plans / manifests / staging
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_MIG_TRANSFER_LOCAL=1 SOVIEZ_MIG_FREEZE_FIXTURE=1 SOVIEZ_MIG_FORCE_FIXTURE_DB=1
unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_REAL_MTLS SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES \
  SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER \
  SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB \
  SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT SOVIEZ_MIG_REAL_ERP_STAGING 2>/dev/null || true
export SOVIEZ_MIG_FORCE_FIXTURE_ERP=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p19-mt.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-mt","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'

mk_pair() {
  local prod="$1" lic="$2" dig="$3" domain="$4"
  export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$dig"
  export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
  SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'$prod','environment_id':'$prod','license_id':'$lic','database_uuid':'11111111-1111-1111-1111-111111111111','image_digest':'$dig','domain':'$domain','erp_version':'18.0','postgresql_major':'16'}))")"
  export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$domain\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
  local disc boot pair
  disc="$(soviez_migration_discover_run "$prod")"
  boot="$(soviez_migration_bootstrap_run 1)"
  pair="$(soviez_migration_pair_run "$prod" "$(soviez_json_get "$boot" bootstrap_code)" \
    "$(soviez_json_get "$disc" identity.host_identity.fingerprint)" \
    "$(soviez_json_get "$boot" public_fingerprint)" "$lic" "$prod" "$(soviez_json_get "$boot" bootstrap_id)" 1)"
  soviez_json_get "$pair" migration_pair_id
}

mk_routing() {
  local pair_id="$1"
  local rid
  rid="$(soviez_migration_new_id rplan)"
  mkdir -p "$(soviez_migration_routing_plan_dir "$rid")"
  python3 - <<PY
import json, datetime
p="$(soviez_migration_routing_plan_dir "$rid")/object.json"
open(p,"w").write(json.dumps({
  "plan_id":"$rid","migration_pair_id":"$pair_id","result":"PASS",
  "issued_at":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at":(datetime.datetime.utcnow()+datetime.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$(soviez_migration_routing_plan_dir "$rid")/object.json"
  printf '%s\n' "$rid"
}

PA="$(mk_pair prod-a lic-a sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa a.example.test)"
PB="$(mk_pair prod-b lic-b sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb b.example.test)"
[[ "$PA" != "$PB" ]]
RA="$(mk_routing "$PA")"
RB="$(mk_routing "$PB")"

PLAN_A="$(soviez_migration_transfer_plan_run "$PA" "$RA")"
PLAN_B="$(soviez_migration_transfer_plan_run "$PB" "$RB")"
[[ "$(soviez_json_get "$PLAN_A" transfer_plan_id)" != "$(soviez_json_get "$PLAN_B" transfer_plan_id)" ]]
[[ "$(soviez_json_get "$PLAN_A" migration_pair_id)" == "$PA" ]]
[[ "$(soviez_json_get "$PLAN_B" migration_pair_id)" == "$PB" ]]

# Cross-pair routing denied
if ( soviez_migration_transfer_require_routing "$PA" "$RB" ) 2>/dev/null; then
  echo "FAIL: cross-pair routing accepted"; exit 1
fi

OUT_A="$(soviez_migration_transfer_start "$PA" "$RA")"
OUT_B="$(soviez_migration_transfer_start "$PB" "$RB")"
SA="$(soviez_json_get "$OUT_A" destination_staging_id)"
SB="$(soviez_json_get "$OUT_B" destination_staging_id)"
[[ "$SA" != "$SB" ]]
[[ -d "$(soviez_migration_staging_dir "$SA")" && -d "$(soviez_migration_staging_dir "$SB")" ]]

# Abort A must not delete B staging
soviez_migration_transfer_abort "$(soviez_json_get "$OUT_A" operation_id)" >/dev/null
[[ -d "$(soviez_migration_staging_dir "$SB")" ]]

echo "test_phase19_multi_tenant_isolation: PASS"
