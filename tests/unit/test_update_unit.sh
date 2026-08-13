#!/usr/bin/env bash
# Phase 15 — Safe Update unit tests
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
unset SOVIEZ_UPDATE_REAL_DOCKER SOVIEZ_UPDATE_REAL_IMAGE SOVIEZ_UPDATE_CANDIDATE_HOST_ROOT \
  SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL SOVIEZ_UPDATE_FIXTURE_UPGRADE_FAIL 2>/dev/null || true
export SOVIEZ_UPDATE_REAL_DOCKER=0
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p15-unit.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
soviez_ssl_paths_init 2>/dev/null || true
soviez_ops_paths_init
soviez_update_paths_init

HOST="$(hostname -f 2>/dev/null || hostname || echo unknown)"
PROD_A="prod-a-p15"
PROD_B="prod-b-p15"
LIC_A="lic-annual-a"
LIC_B="lic-annual-b"
DIGEST_OLD="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
DIGEST_NEW="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

setup_prod() {
  local tid="$1" lic="$2" digest="$3"
  local uuid
  case "$tid" in
    prod-a-p15) uuid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" ;;
    prod-b-p15) uuid="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" ;;
    *) uuid="cccccccc-cccc-cccc-cccc-cccccccccccc" ;;
  esac
  local tdir="$SOVIEZ_TENANT_DIR/$tid"
  mkdir -p "$tdir/db" "$tdir/filestore" "$tdir/addons"
  printf 'db-data-%s\n' "$tid" > "$tdir/db/dump.sql"
  printf 'fs-%s\n' "$tid" > "$tdir/filestore/file1"
  python3 - <<PY > "$tdir/identity.json"
import json
print(json.dumps({
  "tenant_id":"$tid",
  "environment_id":"$tid",
  "license_id":"$lic",
  "account_id":"acct-1",
  "database_uuid":"$uuid",
  "fingerprint":"fp-$tid",
  "production_fingerprint":"fp-$tid",
  "container":"soviez-web-$tid",
  "container_status":"running",
  "current_digest":"$digest",
  "image_digest":"$digest",
  "erp_major":"18",
  "host_identity":"$HOST",
  "database_path":"$tdir/db",
  "filestore_path":"$tdir/filestore",
  "addons_path":"$tdir/addons",
  "database_bytes":4096,
  "filestore_bytes":4096,
  "image_bytes":1048576,
},separators=(",",":")))
PY
}

setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD"
setup_prod "$PROD_B" "$LIC_B" "$DIGEST_OLD"

# Stage fixture for denial
mkdir -p "$SOVIEZ_STAGES_DIR/stage-x"
printf '{"stage_id":"stage-x","parent_production_tenant_id":"%s"}\n' "$PROD_A" > "$SOVIEZ_STAGES_DIR/stage-x/identity.json"

export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-annual-a","account_id":"acct-1","decision":"allow"}'
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON
SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "release_id":"rel-p15-1",
  "digest":"$DIGEST_NEW",
  "image_digest":"$DIGEST_NEW",
  "signed":True,
  "signature":"sig-valid-fixture",
  "architecture":"$(uname -m)",
  "erp_major":"18",
  "image_ref":"soviez/erp@$DIGEST_NEW",
  "notes_ref":"notes://rel-p15-1",
},separators=(",",":")))
PY
)"
export SOVIEZ_UPDATE_FIXTURE_PULL_SESSION_JSON='{"ok":true,"token":"ephemeral-token","expires_in":60}'

# --- Targeting ---
set +e
out="$(soviez_update_run "" "" "" 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "missing target must fail" >&2; exit 1; }
assert_contains "$out" UPDATE_TARGET_REQUIRED

set +e
out="$(soviez_update_run "all" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_TARGET_INVALID

set +e
out="$(soviez_update_run "*" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_TARGET_INVALID

set +e
out="$(soviez_update_run "stage-x" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_STAGE_TARGET_DENIED

# --- Entitlement: monthly denied ---
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":false,"capability":"product_updates","source_type":"legacy_monthly","license_id":"lic-annual-a","denial_code":"UPDATE_MONTHLY_SUPPORT_DENIED"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_MONTHLY_SUPPORT_DENIED

# wrong license
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-OTHER","account_id":"acct-1"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_WRONG_LICENSE

# unbound
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"unbound_legacy","license_id":"lic-annual-a"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_UNBOUND_GRANT_DENIED

# expired
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":false,"capability":"product_updates","source_type":"annual_support","license_id":"lic-annual-a","denial_code":"EXPIRED"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_CAPABILITY_EXPIRED

# provider-neutral admin grant allowed + happy path connected
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"admin_complimentary","license_id":"lic-annual-a","account_id":"acct-1","decision":"allow"}'
out="$(soviez_update_run "$PROD_A" "rel-p15-1" "" 1)"
assert_contains "$out" UPDATE_COMPLETED
assert_eq "$DIGEST_NEW" "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/current_digest.txt")"
# Production B unchanged
assert_eq "$DIGEST_OLD" "$(soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD_B/identity.json")" current_digest)"

# --- Release: unsigned ---
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD"
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-annual-a","account_id":"acct-1"}'
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON='{"release_id":"bad","digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","signed":false,"signature":"","architecture":"'"$(uname -m)"'","erp_major":"18"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_RELEASE_UNSIGNED

# bad signature
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON='{"release_id":"bad2","digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","signed":true,"signature":"tampered","architecture":"'"$(uname -m)"'","erp_major":"18"}'
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_RELEASE_SIGNATURE_INVALID

# already current
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({"release_id":"same","digest":"$DIGEST_OLD","signed":True,"signature":"sig","architecture":"$(uname -m)","erp_major":"18"},separators=(",",":")))
PY
)"
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_ALREADY_CURRENT

# Reset offline flag between connected cases
unset SOVIEZ_UPDATE_OFFLINE_MODE 2>/dev/null || true

# --- Disk insufficient ---
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({"release_id":"rel-p15-1","digest":"$DIGEST_NEW","signed":True,"signature":"sig","architecture":"$(uname -m)","erp_major":"18","image_ref":"soviez/erp@$DIGEST_NEW"},separators=(",",":")))
PY
)"
export SOVIEZ_UPDATE_FIXTURE_AVAILABLE_BYTES=100
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_DISK_INSUFFICIENT
# Production still old
assert_eq "$DIGEST_OLD" "$(soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/identity.json")" current_digest)"
unset SOVIEZ_UPDATE_FIXTURE_AVAILABLE_BYTES

# --- Addon failure blocks switch ---
export SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL=1
set +e
out="$(soviez_update_run "$PROD_A" "" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_CANDIDATE_UPGRADE_FAILED
assert_eq "$DIGEST_OLD" "$(soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/identity.json")" current_digest)"
unset SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL

# --- Conflicts ---
assert_eq "deny" "$(soviez_ops_conflict_decide production_update migrate env1 env1 1)"
assert_eq "deny" "$(soviez_ops_conflict_decide production_update restore env1 env1 1)"
assert_eq "attach_existing" "$(soviez_ops_conflict_decide production_update production_update env1 env1 1)"
assert_eq "allow" "$(soviez_ops_conflict_decide production_update production_update env1 env2 0)"

# --- Offline package ---
pkgdir="$SOVIEZ_ROOT/offline-pkg"
mkdir -p "$pkgdir"
python3 - <<PY > "$pkgdir/package.json"
import json
print(json.dumps({
  "package_id":"off-pkg-1",
  "nonce":"off-pkg-1",
  "signed":True,
  "signature":"offline-sig-ok",
  "digest":"$DIGEST_NEW",
  "license_id":"$LIC_A",
  "production_environment_id":"$PROD_A",
  "capability":"product_updates",
  "entitlement_ok":True,
  "architecture":"$(uname -m)",
  "erp_major":"18",
  "release_id":"rel-offline-1",
  "expires_at":"2099-01-01T00:00:00Z",
},separators=(",",":")))
PY
# Clear image cache pull path
out="$(soviez_update_run "$PROD_A" "" "$pkgdir" 1)"
assert_contains "$out" UPDATE_COMPLETED

# Replay denied
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD"
set +e
out="$(soviez_update_run "$PROD_A" "" "$pkgdir" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_OFFLINE_PACKAGE_INVALID

# --- Rollback after switch fail ---
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD"
pkgdir2="$SOVIEZ_ROOT/offline-pkg2"
mkdir -p "$pkgdir2"
python3 - <<PY > "$pkgdir2/package.json"
import json
print(json.dumps({
  "package_id":"off-pkg-2","nonce":"off-pkg-2","signed":True,"signature":"ok",
  "digest":"$DIGEST_NEW","license_id":"$LIC_A","production_environment_id":"$PROD_A",
  "capability":"product_updates","entitlement_ok":True,"architecture":"$(uname -m)",
  "erp_major":"18","release_id":"rel-off-2","expires_at":"2099-01-01T00:00:00Z",
},separators=(",",":")))
PY
export SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL=1
set +e
out="$(soviez_update_run "$PROD_A" "" "$pkgdir2" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_SWITCH_FAILED
assert_eq "$DIGEST_OLD" "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/current_digest.txt" 2>/dev/null || soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/identity.json")" current_digest)"
unset SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL

# Cancel boundary
assert_eq "irreversible" "$(soviez_update_cancel_boundary switching)"
assert_eq "cancelable" "$(soviez_update_cancel_boundary running_preflight)"

echo "PASS test_update_unit"
rm -rf "$SOVIEZ_ROOT"
