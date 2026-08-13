#!/usr/bin/env bash
# Phase 17 — secret handling audit
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-sec.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((50*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=1000000
DIGEST="sha256:$(printf sec | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c 'import json; print(json.dumps({"tenant_id":"prod-sec","environment_id":"prod-sec","license_id":"lic-sec","database_uuid":"66666666-6666-6666-6666-666666666666","image_digest":"'"$DIGEST"'","erp_version":"18.0","postgresql_major":"16"}))')"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-sec)"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"; BID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
LIC="$(soviez_json_get "$DISC" identity.license_id)"
PAIR="$(soviez_migration_pair_run prod-sec "$CODE" "$SRC" "$DST" "$LIC" prod-sec "$BID" 1)"
PID="$(soviez_json_get "$PAIR" migration_pair_id)"

# Device private key mode
PRIV="$(soviez_device_private_key_file)"
[[ -f "$PRIV" ]]
[[ "$(stat -f '%Lp' "$PRIV" 2>/dev/null || stat -c '%a' "$PRIV")" =~ ^600$|^0600$ ]]

# Trust keys 600; absent from reports
[[ -f "$SOVIEZ_MIG_TRUST_DIR/$PID/source.key" ]]
[[ "$(stat -f '%Lp' "$SOVIEZ_MIG_TRUST_DIR/$PID/source.key" 2>/dev/null || stat -c '%a' "$SOVIEZ_MIG_TRUST_DIR/$PID/source.key")" =~ 600 ]]
! rg -n 'BEGIN (EC )?PRIVATE KEY' "$(soviez_migration_pair_dir "$PID")/object.json" "$(soviez_migration_discovery_dir "$(soviez_json_get "$DISC" discovery_id)")/object.json"

soviez_migration_abort_run "$PID" >/dev/null
[[ -f "$SOVIEZ_MIG_TRUST_DIR/$PID/REVOKED" ]]
# Keys removed on abort
[[ ! -f "$SOVIEZ_MIG_TRUST_DIR/$PID/source.key" ]]

# No secrets in generated installer header region
! rg -n 'BEGIN PRIVATE KEY|password=|SECRET=' "$ROOT/dist/soviez.sh" | head -5 | grep -q .

echo "test_phase17_secret_handling: PASS"
