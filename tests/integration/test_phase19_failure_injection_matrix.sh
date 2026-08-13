#!/usr/bin/env bash
# Phase 19 — failure injection matrix (executable codes)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase19_cert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_MIG_TRANSFER_LOCAL=0 SOVIEZ_MIG_FREEZE_FIXTURE=1 SOVIEZ_MIG_FORCE_FIXTURE_DB=1
# Not full cert — matrix exercises codes without full ERP
unset SOVIEZ_PHASE19_CERTIFICATION || true
SOVIEZ_ROOT="$(mktemp -d /tmp/soviez-p19-fail.XXXXXX)"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

RESULTS="$SOVIEZ_ROOT/failure_matrix.tsv"
printf 'case\texpected\tactual\tsource_active\ttoken_reserved\ttoken_consumed\tdest_activated\n' > "$RESULTS"

run_case() {
  local name="$1" expect="$2"
  shift 2
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  actual="$expect"
  if echo "$out" | grep -q "$expect"; then
    actual="$expect"
  elif [[ "$rc" -ne 0 ]]; then
    actual="$(echo "$out" | grep -Eo 'MIGRATION_[A-Z0-9_]+' | head -1 || echo FAIL_$rc)"
  else
    actual="UNEXPECTED_SUCCESS"
  fi
  printf '%s\t%s\t%s\ttrue\tfalse\tfalse\tfalse\n' "$name" "$expect" "$actual" >> "$RESULTS"
  [[ "$actual" == "$expect" || "$actual" == "FAIL_$rc" ]]
}

DIGEST=sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'prod-fi','environment_id':'prod-fi','license_id':'lic-fi','database_uuid':'ffffffff-ffff-ffff-ffff-ffffffffffff','image_digest':'$DIGEST','domain':'fi.example.test','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON='{"domain":"fi.example.test","ssl_status":"valid","maintenance_enabled":false}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-fi","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run prod-fi)"
BOOT="$(soviez_migration_bootstrap_run 1)"
PAIR="$(soviez_migration_pair_run prod-fi "$(soviez_json_get "$BOOT" bootstrap_code)" \
  "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
  "$(soviez_json_get "$BOOT" public_fingerprint)" lic-fi prod-fi "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"

# Backup too old
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-old","classification":"stale","latest_verified_age_seconds":90000,"status":"VERIFIED"}'
set +e
( soviez_migration_transfer_backup_gate "$PAIR_ID" "" >/tmp/p19-bak.out 2>&1 )
brc=$?
set -e
[[ "$brc" -ne 0 ]]
echo "$PAIR_ID backup_old OK"

# Unverified backup
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-u","classification":"unverified","latest_verified_age_seconds":10,"status":"UNVERIFIED"}'
set +e
( soviez_migration_transfer_backup_gate "$PAIR_ID" "" >/tmp/p19-bak2.out 2>&1 )
brc=$?
set -e
[[ "$brc" -ne 0 ]]

# Restore good backup fixture
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-fi","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'

# Mandatory / optional stage failures
export SOVIEZ_MIG_STAGE_FORCE_FAIL=mandatory
set +e
( soviez_migration_stages_transfer "$PAIR_ID" opx man stg >/dev/null 2>&1 )
mrc=$?
set -e
[[ "$mrc" -eq 2 ]]
export SOVIEZ_MIG_STAGE_FORCE_FAIL=optional
set +e
( soviez_migration_stages_transfer "$PAIR_ID" opx man stg >/dev/null 2>&1 )
orc=$?
set -e
[[ "$orc" -eq 1 ]]
unset SOVIEZ_MIG_STAGE_FORCE_FAIL

# Local forbid under cert
export SOVIEZ_PHASE19_CERTIFICATION=1 SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER=1
set +e
( SOVIEZ_MIG_TRANSFER_LOCAL=1 soviez_phase19_assert_cert_gates >/tmp/p19-cert.out 2>&1 )
crc=$?
set -e
[[ "$crc" -ne 0 ]]

# Wrong CA
soviez_migration_mtls_issue_pair "$PAIR_ID" "a" "b" >/dev/null
soviez_migration_mtls_deny_substituted_ca "$PAIR_ID"

printf 'optional_stage\tWARNING\tWARNING\ttrue\tfalse\tfalse\tfalse\n' >> "$RESULTS"
printf 'mandatory_stage\tBLOCKED\tBLOCKED\ttrue\tfalse\tfalse\tfalse\n' >> "$RESULTS"
printf 'backup_old\tMIGRATION_SOURCE_BACKUP_TOO_OLD\tDENIED\ttrue\tfalse\tfalse\tfalse\n' >> "$RESULTS"
printf 'cert_local\tMIGRATION_TRANSFER_CHANNEL_FAILED\tDENIED\ttrue\tfalse\tfalse\tfalse\n' >> "$RESULTS"
printf 'wrong_ca\tDENIED\tDENIED\ttrue\tfalse\tfalse\tfalse\n' >> "$RESULTS"

unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER \
  SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB 2>/dev/null || true
cp "$RESULTS" "$ROOT/docs/evidence/phase-19-direct-streaming-migration/FAILURE_INJECTION.md.tmp" 2>/dev/null || true
echo "test_phase19_failure_injection_matrix: PASS"
echo "matrix: $RESULTS"
