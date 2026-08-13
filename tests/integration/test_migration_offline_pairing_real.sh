#!/usr/bin/env bash
# Phase 17 final — offline pairing (no-network) real export/import/replay
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_OFFLINE=1
export http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 ALL_PROXY=http://127.0.0.1:1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-off.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
DIGEST="sha256:$(printf off | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-off","environment_id":"prod-off","license_id":"lic-off","database_uuid":"22222222-2222-2222-2222-222222222222","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"not_checked_offline","consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-off)"
DID="$(soviez_json_get "$DISC" discovery_id)"
BOOT="$(soviez_migration_bootstrap_run 1)"
BID="$(soviez_json_get "$BOOT" bootstrap_id)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
LIC="$(soviez_json_get "$DISC" identity.license_id)"
PAIR="$(soviez_migration_pair_run prod-off "$CODE" "$SRC" "$DST" "$LIC" prod-off "$BID" 1)"
PID="$(soviez_json_get "$PAIR" migration_pair_id)"
READY="$(soviez_migration_readiness_run "$PID")"
RID="$(soviez_json_get "$READY" report_id)"

OUTD="$SOVIEZ_ROOT/offline-out"
mkdir -p "$OUTD"
soviez_migration_offline_export discovery "$DID" "$OUTD/disc.json" >/dev/null
soviez_migration_offline_export bootstrap "$BID" "$OUTD/boot.json" >/dev/null
soviez_migration_offline_export pair "$PID" "$OUTD/pair.json" >/dev/null
soviez_migration_offline_export readiness "$RID" "$OUTD/ready.json" >/dev/null

! rg -n 'BEGIN (EC )?PRIVATE KEY' "$OUTD" || { echo "FAIL private key export"; exit 1; }
python3 - <<PY
import json
for name in ("disc","boot","pair","ready"):
  d=json.load(open("$OUTD/%s.json"%name))
  assert d.get("data_transfer_authorized") is False
  assert d.get("permanent_private_key_exported") is False
print("offline_meta_ok")
PY

# Quarantine import + replay deny (same root)
soviez_migration_offline_import "$OUTD/pair.json" >/dev/null
( soviez_migration_offline_import "$OUTD/pair.json" ) 2>/dev/null && { echo "FAIL replay"; exit 1; } || true

echo "test_migration_offline_pairing_real: PASS"
