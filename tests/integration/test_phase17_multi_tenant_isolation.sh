#!/usr/bin/env bash
# Phase 17 final — multi-tenant isolation
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-mt.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

mk_prod() {
  local tid="$1" lic="$2" dig="$3"
  T="$tid" L="$lic" D="$dig" python3 - <<'PY'
import json, os, uuid
print(json.dumps({
  "tenant_id": os.environ["T"],
  "environment_id": os.environ["T"],
  "license_id": os.environ["L"],
  "database_uuid": str(uuid.uuid4()),
  "image_digest": os.environ["D"],
  "erp_version": "18.0",
  "postgresql_major": "16",
}))
PY
}

DIGEST_A="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
DIGEST_B="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST_A"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON="$(python3 -c 'import json; print(json.dumps({"stages":[{"stage_id":"sa","parent_production_id":"prod-a","status":"active","retention_deadline":"2099-01-01","database_bytes":1,"filestore_bytes":1,"selectable":True,"owner_selected":False,"selectable_reason":"ok"}]}))')"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(mk_prod prod-a lic-a "$DIGEST_A")"
DISC_A="$(soviez_migration_discover_run prod-a)"
BOOT_A="$(soviez_migration_bootstrap_run 1)"
CODE_A="$(soviez_json_get "$BOOT_A" bootstrap_code)"; BID_A="$(soviez_json_get "$BOOT_A" bootstrap_id)"
SRC_A="$(soviez_json_get "$DISC_A" identity.host_identity.fingerprint)"
DST_A="$(soviez_json_get "$BOOT_A" public_fingerprint)"

export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST_B"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON="$(python3 -c 'import json; print(json.dumps({"stages":[{"stage_id":"sb","parent_production_id":"prod-b","status":"active","retention_deadline":"2099-01-01","database_bytes":1,"filestore_bytes":1,"selectable":True,"owner_selected":False,"selectable_reason":"ok"}]}))')"
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(mk_prod prod-b lic-b "$DIGEST_B")"
DISC_B="$(soviez_migration_discover_run prod-b)"
BOOT_B="$(soviez_migration_bootstrap_run 1)"
CODE_B="$(soviez_json_get "$BOOT_B" bootstrap_code)"; BID_B="$(soviez_json_get "$BOOT_B" bootstrap_id)"
SRC_B="$(soviez_json_get "$DISC_B" identity.host_identity.fingerprint)"
DST_B="$(soviez_json_get "$BOOT_B" public_fingerprint)"

# Cross-license denied
( soviez_migration_pair_run prod-a "$CODE_A" "$SRC_A" "$DST_A" lic-b prod-a "$BID_A" 1 ) 2>/dev/null && exit 1 || true
# Cross-production confirmation denied
( soviez_migration_pair_run prod-a "$CODE_A" "$SRC_A" "$DST_A" lic-a prod-b "$BID_A" 1 ) 2>/dev/null && exit 1 || true
# Cross-destination bootstrap id denied
( soviez_migration_pair_run prod-a "$CODE_A" "$SRC_A" "$DST_A" lic-a prod-a "$BID_B" 1 ) 2>/dev/null && exit 1 || true

PAIR_A="$(soviez_migration_pair_run prod-a "$CODE_A" "$SRC_A" "$DST_A" lic-a prod-a "$BID_A" 1)"
PID_A="$(soviez_json_get "$PAIR_A" migration_pair_id)"
# Bootstrap code reuse denied
( soviez_migration_pair_run prod-a "$CODE_A" "$SRC_A" "$DST_A" lic-a prod-a "$BID_A" 1 ) 2>/dev/null && exit 1 || true

PAIR_B="$(soviez_migration_pair_run prod-b "$CODE_B" "$SRC_B" "$DST_B" lic-b prod-b "$BID_B" 1)"
PID_B="$(soviez_json_get "$PAIR_B" migration_pair_id)"
[[ "$PID_A" != "$PID_B" ]]

soviez_migration_stage_select "$PID_A" sa select >/dev/null
SEL_A="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID_A")/object.json")" selected_stage_ids)"
SEL_B="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PID_B")/object.json")" selected_stage_ids)"
[[ "$SEL_A" == *sa* ]]
[[ "$SEL_B" == "[]" || "$SEL_B" == "" ]]

echo "test_phase17_multi_tenant_isolation: PASS"
