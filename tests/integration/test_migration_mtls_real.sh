#!/usr/bin/env bash
# Phase 17 final — real mTLS handshake + MITM denial
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_MTLS_LOOPBACK=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-mtls.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_ops_paths_init 2>/dev/null || true; soviez_migration_paths_init; soviez_device_ensure_keys

export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=5000000
DIGEST="sha256:$(printf mtls | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-mtls","environment_id":"prod-mtls","license_id":"lic-mtls","database_uuid":"11111111-1111-1111-1111-111111111111","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-mtls)"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"; BID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
LIC="$(soviez_json_get "$DISC" identity.license_id)"
PAIR="$(soviez_migration_pair_run prod-mtls "$CODE" "$SRC" "$DST" "$LIC" prod-mtls "$BID" 1)"
PID="$(soviez_json_get "$PAIR" migration_pair_id)"

RES="$(soviez_migration_mtls_connectivity_test "$PID")"
[[ "$RES" == ok-handshake || "$RES" == ok ]] || { echo "FAIL mtls $RES"; exit 1; }
[[ "$RES" == ok-handshake ]] || { echo "FAIL expected handshake mode got $RES"; exit 1; }

soviez_migration_mtls_deny_substituted_ca "$PID" || { echo "FAIL MITM not denied"; exit 1; }

# Wrong fingerprint
BOOT2="$(soviez_migration_bootstrap_run 1)"
CODE2="$(soviez_json_get "$BOOT2" bootstrap_code)"; BID2="$(soviez_json_get "$BOOT2" bootstrap_id)"
DST2="$(soviez_json_get "$BOOT2" public_fingerprint)"
( soviez_migration_pair_run prod-mtls "$CODE2" wrong "$DST2" "$LIC" prod-mtls "$BID2" 1 ) 2>/dev/null && exit 1 || true

# Private keys not in pair object
! grep -E 'BEGIN (EC |PRIVATE)|private_key' "$(soviez_migration_pair_dir "$PID")/object.json"

echo "test_migration_mtls_real: PASS"
