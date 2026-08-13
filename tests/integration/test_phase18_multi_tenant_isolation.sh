#!/usr/bin/env bash
# Phase 18 — multi-tenant isolation for domain plans / challenges / landings
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p18-mt.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_DNS_ZONE_DIR="$SOVIEZ_ROOT/dns_zone"
mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'

mk_pair() {
  local prod="$1" lic="$2" dig="$3" domain="$4"
  export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$dig"
  export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
  SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'$prod','environment_id':'$prod','license_id':'$lic','database_uuid':'11111111-1111-1111-1111-111111111111','image_digest':'$dig','domain':'$domain','erp_version':'18.0','postgresql_major':'16'}))")"
  export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$domain\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
  local disc boot code bid src dst pair
  disc="$(soviez_migration_discover_run "$prod")"
  boot="$(soviez_migration_bootstrap_run 1)"
  code="$(soviez_json_get "$boot" bootstrap_code)"; bid="$(soviez_json_get "$boot" bootstrap_id)"
  src="$(soviez_json_get "$disc" identity.host_identity.fingerprint)"
  dst="$(soviez_json_get "$boot" public_fingerprint)"
  pair="$(soviez_migration_pair_run "$prod" "$code" "$src" "$dst" "$lic" "$prod" "$bid" 1)"
  soviez_json_get "$pair" migration_pair_id
}

PA="$(mk_pair prod-a lic-a sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa a.example.test)"
PB="$(mk_pair prod-b lic-b sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb b.example.test)"
[[ "$PA" != "$PB" ]]

PLAN_A="$(soviez_migration_domain_plan_run "$PA")"
PLAN_B="$(soviez_migration_domain_plan_run "$PB")"
[[ "$(soviez_json_get "$PLAN_A" migration_fqdn)" == "migrate.a.example.test" ]]
[[ "$(soviez_json_get "$PLAN_B" migration_fqdn)" == "migrate.b.example.test" ]]

CH_A="$(soviez_migration_dns_challenge_create "$PA" "$(soviez_json_get "$PLAN_A" domain_plan_id)")"
CH_B="$(soviez_migration_dns_challenge_create "$PB" "$(soviez_json_get "$PLAN_B" domain_plan_id)")"
[[ "$(soviez_json_get "$CH_A" challenge_id)" != "$(soviez_json_get "$CH_B" challenge_id)" ]]
[[ "$(soviez_json_get "$CH_A" migration_fqdn)" != "$(soviez_json_get "$CH_B" migration_fqdn)" ]]

soviez_migration_landing_prepare "$PA" >/dev/null
soviez_migration_landing_prepare "$PB" >/dev/null
SA="$(soviez_migration_landing_site_dir "$(soviez_migration_landing_site_id "$PA")")"
SB="$(soviez_migration_landing_site_dir "$(soviez_migration_landing_site_id "$PB")")"
[[ "$SA" != "$SB" ]]
[[ -d "$SA" && -d "$SB" ]]

soviez_migration_domain_abort "$PA" >/dev/null
[[ ! -d "$SA/www" ]] || [[ ! -f "$SA/www/index.html" ]]
[[ -f "$SB/www/index.html" ]]

echo "test_phase18_multi_tenant_isolation: PASS"
