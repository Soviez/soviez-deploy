#!/usr/bin/env bash
# Phase 16 final — real ERP restore-test candidate (/web/login) + failure injections.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required" >&2; exit 1; }
docker image inspect soviez/erp:p15-v15-labeled >/dev/null 2>&1 || {
  echo "FAIL: soviez/erp:p15-v15-labeled required" >&2; exit 1
}
docker image inspect postgres:16 >/dev/null 2>&1 || docker pull postgres:16 >/dev/null

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_RESTORE_TEST_REAL=1
export SOVIEZ_BACKUP_RESTORE_TEST_IMAGE=soviez/erp:p15-v15-labeled
export SOVIEZ_BACKUP_RESTORE_TEST_PG_NAME=soviez-bk-rtest-pg-cert
export SOVIEZ_BACKUP_RESTORE_TEST_CLEAN=1
export SOVIEZ_BACKUP_PASSPHRASE="p16-rtest-passphrase-not-production"
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_MIGRATION_SECRET=phase16-disposable-migration-secret-not-production
export SOVIEZ_ROOT="$ROOT/.tmp/p16-rtest-real-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
export SOVIEZ_BACKUP_RESTORE_TEST_HOST_ROOT="$SOVIEZ_ROOT/rtest-host"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init

HOST="$(hostname -f 2>/dev/null || hostname)"
PROD=prod-rtest-real
mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore" "$SOVIEZ_TENANT_DIR/$PROD/addons"
printf 'attachment-bytes\n' > "$SOVIEZ_TENANT_DIR/$PROD/filestore/att1"
printf 'db\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic-rtest","database_uuid":"33333333-3333-3333-3333-333333333333",
  "database_name":"db_rtest_real","host_identity":"$HOST","fingerprint":"fp-$PROD",
  "production_fingerprint":"fp-$PROD","erp_major":"18",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "addons_path":"$SOVIEZ_TENANT_DIR/$PROD/addons",
  "current_digest":"$(docker image inspect soviez/erp:p15-v15-labeled --format '{{.Id}}')",
},separators=(",",":")))
PY

# Create verified encrypted full backup (local)
out="$(soviez_backup_run "$PROD" local-primary full 1)"
echo "$out" | grep -q BACKUP_COMPLETED || { echo "backup failed: $out" >&2; exit 1; }
BID="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
soviez_backup_verify_level1 "$BID" >/dev/null
obj="$(soviez_backup_read_object "$BID")"
echo "$obj" | grep -q VERIFIED

# Real restore-test
rt="$(soviez_backup_restore_test "$BID")"
echo "$rt" | grep -q RESTORE_TESTED || { echo "restore-test failed: $rt" >&2; exit 1; }
obj2="$(soviez_backup_read_object "$BID")"
echo "$obj2" | grep -q RESTORE_TESTED

# Permanent slot not consumed — identity contract
# (candidate cleaned; check code path wrote license_slot=none before clean — re-run without clean once)
export SOVIEZ_BACKUP_RESTORE_TEST_CLEAN=0
# New backup for second pass
out2="$(soviez_backup_run "$PROD" local-primary full 1)"
BID2="$(echo "$out2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
soviez_backup_verify_level1 "$BID2" >/dev/null
rt2="$(soviez_backup_restore_test "$BID2")"
echo "$rt2" | grep -q RESTORE_TESTED
cdir="$(echo "$rt2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["candidate_dir"])')"
grep -q 'license_slot=none' "$cdir/runtime/identity.txt"
grep -q 'slot_consumed=false' "$cdir/runtime/license_guard.txt"
grep -q '"login":"pass"' "$cdir/runtime/http_validation.json"
[[ -f "$cdir/runtime/modules_ok.txt" ]]
export SOVIEZ_BACKUP_RESTORE_TEST_CLEAN=1

# Failure injections preserve VERIFIED (not RESTORE_TESTED on fail)
inject_fail() {
  local inj="$1" bid
  outi="$(soviez_backup_run "$PROD" local-primary full 1)"
  bid="$(echo "$outi" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
  soviez_backup_verify_level1 "$bid" >/dev/null
  set +e
  bash -c '
    source "'"$ROOT"'/dist/soviez.sh"
    export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_RESTORE_TEST_REAL=1
    export SOVIEZ_BACKUP_RESTORE_TEST_IMAGE=soviez/erp:p15-v15-labeled
    export SOVIEZ_BACKUP_RESTORE_TEST_PG_NAME=soviez-bk-rtest-pg-cert
    export SOVIEZ_BACKUP_RESTORE_TEST_CLEAN=1
    export SOVIEZ_BACKUP_PASSPHRASE="'"$SOVIEZ_BACKUP_PASSPHRASE"'"
    export SOVIEZ_BACKUP_RESTORE_TEST_INJECT="'"$inj"'"
    export SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'"
    export DOCKER_HOST="'"$DOCKER_HOST"'"
    export SOVIEZ_MIGRATION_SECRET=phase16-disposable-migration-secret-not-production
    soviez_paths_init; soviez_backup_paths_init
    soviez_backup_restore_test "'"$bid"'"
  ' >/dev/null 2>&1
  local rc=$?
  set -e
  [[ $rc -ne 0 ]] || { echo "inject $inj should fail" >&2; exit 1; }
  local st
  st="$(soviez_json_get "$(soviez_backup_read_object "$bid")" verification_status)"
  [[ "$st" == "VERIFIED" ]] || { echo "backup not preserved VERIFIED after $inj" >&2; exit 1; }
  local rtst
  rtst="$(soviez_json_get "$(soviez_backup_read_object "$bid")" restore_test_status 2>/dev/null || echo none)"
  [[ "$rtst" != "RESTORE_TESTED" ]] || { echo "should not be RESTORE_TESTED after $inj" >&2; exit 1; }
}

inject_fail wrong_key
inject_fail tampered_manifest
inject_fail checksum_mismatch
inject_fail corrupt_filestore
inject_fail incompatible_addon
inject_fail login_fail

# Cleanup disposable PG/container leftovers
docker rm -f soviez-bk-rtest-pg-cert 2>/dev/null || true
docker ps -aq --filter 'name=soviez-bk-rtest-' | xargs -r docker rm -f 2>/dev/null || true

echo "PASS test_restore_test_real"
rm -rf "$SOVIEZ_ROOT"
