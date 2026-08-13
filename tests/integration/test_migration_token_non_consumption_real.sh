#!/usr/bin/env bash
# Phase 17 final — Migration Token eligibility without reserve/consume (ledger fixture)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-tok.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

LEDGER="$SOVIEZ_ROOT/commercial_ledger.json"
python3 - <<PY > "$LEDGER"
import json
print(json.dumps({
  "capability":"migration_token",
  "available_quantity":2,
  "quantity_consumed":0,
  "quantity_reserved":0,
  "status":"eligible"
}, indent=2))
PY
BEFORE="$(shasum -a 256 "$LEDGER" | awk '{print $1}')"
export SOVIEZ_MIG_TOKEN_LEDGER_PATH="$LEDGER"
unset SOVIEZ_MIG_FIXTURE_TOKEN_JSON || true

export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
DIGEST="sha256:$(printf tok | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-tok","environment_id":"prod-tok","license_id":"lic-tok","database_uuid":"44444444-4444-4444-4444-444444444444","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'

DISC="$(soviez_migration_discover_run prod-tok)"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"; BID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
LIC="$(soviez_json_get "$DISC" identity.license_id)"
PAIR="$(soviez_migration_pair_run prod-tok "$CODE" "$SRC" "$DST" "$LIC" prod-tok "$BID" 1)"
PID="$(soviez_json_get "$PAIR" migration_pair_id)"

for i in 1 2 3; do
  R="$(soviez_migration_readiness_run "$PID")"
  [[ "$(soviez_json_get "$R" migration_token_consumed)" == "False" ]]
  [[ "$(soviez_json_get "$R" migration_token_reserved)" == "False" ]]
  [[ "$(soviez_json_get "$R" migration_token_eligibility.status)" == "eligible" ]]
done
soviez_migration_abort_run "$PID" >/dev/null

AFTER="$(shasum -a 256 "$LEDGER" | awk '{print $1}')"
[[ "$BEFORE" == "$AFTER" ]] || { echo "FAIL ledger mutated"; exit 1; }
python3 - <<PY
import json
d=json.load(open("$LEDGER"))
assert d["available_quantity"]==2 and d["quantity_consumed"]==0 and d["quantity_reserved"]==0
print("ledger_unchanged")
PY

python3 - <<PY > "$LEDGER"
import json
print(json.dumps({"capability":"migration_token","available_quantity":0,"quantity_consumed":0,"quantity_reserved":0,"status":"unavailable"}))
PY
TOK="$(soviez_migration_token_eligibility)"
[[ "$(soviez_json_get "$TOK" status)" == "unavailable" ]]

export SOVIEZ_MIG_OFFLINE=1
TOK2="$(soviez_migration_token_eligibility)"
[[ "$(soviez_json_get "$TOK2" status)" == "not_checked_offline" ]]

echo "test_migration_token_non_consumption_real: PASS"
