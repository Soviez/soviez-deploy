#!/usr/bin/env bash
# Phase 18 — reboot recovery for domain ops (state on host disk; Colima optional)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_ROOT="$ROOT/.tmp/p18-reboot-$$"
rm -rf "$SOVIEZ_ROOT"; mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_DNS_ZONE_DIR="$SOVIEZ_ROOT/dns_zone"
mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
printf 'owner\n' > "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt"

DIGEST="sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'prod-rb','environment_id':'prod-rb','license_id':'lic-rb','database_uuid':'cccccccc-cccc-cccc-cccc-cccccccccccc','image_digest':'$DIGEST','domain':'rb.example.test','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON='{"domain":"rb.example.test","ssl_status":"valid","maintenance_enabled":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-rb)"
BOOT="$(soviez_migration_bootstrap_run 1)"
PAIR="$(soviez_migration_pair_run prod-rb "$(soviez_json_get "$BOOT" bootstrap_code)" \
  "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
  "$(soviez_json_get "$BOOT" public_fingerprint)" lic-rb prod-rb "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"
PLAN="$(soviez_migration_domain_plan_run "$PAIR_ID")"
PLAN_ID="$(soviez_json_get "$PLAN" plan_id)"
CH="$(soviez_migration_dns_challenge_create "$PAIR_ID" "$PLAN_ID")"
CH_ID="$(soviez_json_get "$CH" challenge_id)"
OP="$(soviez_json_get "$CH" operation_id)"
mkdir -p "$SOVIEZ_MIG_ROOT/ops/$OP"
printf '{"operation_id":"%s","operation_type":"migration_dns_challenge","current_state":"recovery_required","challenge_id":"%s","pair_id":"%s"}\n' \
  "$OP" "$CH_ID" "$PAIR_ID" > "$SOVIEZ_MIG_ROOT/ops/$OP/state.json"

# Persist IDs
printf '%s\n' "$PAIR_ID" "$PLAN_ID" "$CH_ID" "$OP" > "$SOVIEZ_ROOT/ids.txt"

# Optional Colima host reboot
if [[ "${SOVIEZ_P18_SKIP_COLIMA_REBOOT:-0}" != "1" ]] && command -v colima >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  colima stop >/dev/null 2>&1 || true
  colima start >/dev/null 2>&1 || true
  export DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
  for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
fi

# Re-source after reboot
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init
[[ -f "$(soviez_migration_domain_plan_dir "$PLAN_ID")/object.json" ]]
[[ -f "$(soviez_migration_dns_challenge_dir "$CH_ID")/object.json" ]]
export SOVIEZ_CLI_OP_ID="$OP"
OUT="$(soviez_cmd_migration_recover)"
echo "$OUT" | grep -q recovery_required
[[ -f "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt" ]]

echo "phase18 reboot matrix: PASS"
