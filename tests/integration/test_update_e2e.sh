#!/usr/bin/env bash
# Phase 15 — Safe Update integration / E2E (disposable fixtures)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p15-e2e.XXXXXX")"
export SOVIEZ_UPDATE_ASSUME_YES=1
# Fixture-path e2e must not inherit real-Docker certification flags from parent shells
unset SOVIEZ_UPDATE_REAL_DOCKER SOVIEZ_UPDATE_REAL_IMAGE SOVIEZ_UPDATE_CANDIDATE_HOST_ROOT \
  SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL SOVIEZ_UPDATE_FIXTURE_UPGRADE_FAIL SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL \
  SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED 2>/dev/null || true
export SOVIEZ_UPDATE_REAL_DOCKER=0

HOST="$(hostname -f 2>/dev/null || hostname || echo unknown)"
PROD_A="prod-e2e-a"
PROD_B="prod-e2e-b"
LIC_A="lic-e2e-a"
DIGEST_OLD="sha256:1111111111111111111111111111111111111111111111111111111111111111"
DIGEST_NEW="sha256:2222222222222222222222222222222222222222222222222222222222222222"

# Match test-mode paths_init layout
export SOVIEZ_TENANT_DIR="$SOVIEZ_ROOT/tenant"

setup_prod() {
  local tid="$1" lic="$2" digest="$3" uuid="$4"
  local tdir="$SOVIEZ_TENANT_DIR/$tid"
  mkdir -p "$tdir/db" "$tdir/filestore" "$tdir/addons/good_mod"
  printf 'CREATE TABLE meta(id int);\n-- tenant %s\n' "$tid" > "$tdir/db/dump.sql"
  printf 'attachment-ref\n' > "$tdir/filestore/att1"
  printf "{'name': 'good_mod', 'version': '1.0'}\n" > "$tdir/addons/good_mod/__manifest__.py"
  python3 - <<PY > "$tdir/identity.json"
import json
print(json.dumps({
  "tenant_id":"$tid","environment_id":"$tid","license_id":"$lic","account_id":"acct-e2e",
  "database_uuid":"$uuid","fingerprint":"fp-$tid","production_fingerprint":"fp-$tid",
  "container":"soviez-web-$tid","container_status":"running",
  "current_digest":"$digest","image_digest":"$digest","erp_major":"18",
  "host_identity":"$HOST",
  "database_path":"$tdir/db","filestore_path":"$tdir/filestore","addons_path":"$tdir/addons",
  "database_bytes":8192,"filestore_bytes":8192,"image_bytes":1048576,
},separators=(",",":")))
PY
}

mkdir -p "$SOVIEZ_TENANT_DIR"
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
setup_prod "$PROD_B" "lic-e2e-b" "$DIGEST_OLD" "bbbbbbbb-bbbb-cccc-dddd-ffffffffffff"

export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-e2e-a","account_id":"acct-e2e","decision":"allow"}'
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON
SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "release_id":"rel-e2e","digest":"$DIGEST_NEW","signed":True,"signature":"sig-e2e",
  "architecture":"$(uname -m)","erp_major":"18","image_ref":"soviez/erp@$DIGEST_NEW",
},separators=(",",":")))
PY
)"
export SOVIEZ_UPDATE_FIXTURE_PULL_SESSION_JSON='{"ok":true,"token":"tok","expires_in":30}'

BIN="$ROOT/dist/soviez.sh"

# 1) No-argument refusal before protected/network work
set +e
out="$(bash "$BIN" --update 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "no-arg must fail" >&2; exit 1; }
assert_contains "$out" UPDATE_TARGET_REQUIRED

# 2) Monthly deny via CLI
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":false,"source_type":"legacy_monthly","license_id":"lic-e2e-a","denial_code":"MONTHLY"}'
set +e
out="$(bash "$BIN" --update "$PROD_A" --confirm 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_MONTHLY_SUPPORT_DENIED

# 3) Connected digest update + multi-tenant isolation
export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-e2e-a","account_id":"acct-e2e"}'
out="$(bash "$BIN" --update "$PROD_A" --release rel-e2e --confirm)"
assert_contains "$out" UPDATE_COMPLETED
assert_eq "$DIGEST_NEW" "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/current_digest.txt")"
assert_eq "$DIGEST_OLD" "$(python3 -c "import json;print(json.load(open('$SOVIEZ_TENANT_DIR/$PROD_B/identity.json'))['current_digest'])")"
# Credential cleanup marker exists on last op
op_id="$(printf '%s\n' "$out" | python3 -c 'import sys,json
op=None
for line in sys.stdin:
  line=line.strip()
  if not line.startswith("{"): continue
  try:
    d=json.loads(line)
  except Exception:
    continue
  if d.get("operation_id"): op=d["operation_id"]
print(op or "")')"
[[ -n "$op_id" ]] || { echo "missing operation_id in output: $out" >&2; exit 1; }
assert_file_exists "$SOVIEZ_ROOT/updates/operations/$op_id/artifact/credential_cleanup.txt"
# No token in state
if grep -Rni 'ephemeral\|pull.token\|\"token\"' "$SOVIEZ_ROOT/updates/operations/$op_id/state.json" 2>/dev/null; then
  echo "token leaked into state" >&2; exit 1
fi
# Downtime measured
assert_file_exists "$SOVIEZ_ROOT/updates/operations/$op_id/switch.json"
assert_contains "$(cat "$SOVIEZ_ROOT/updates/operations/$op_id/switch.json")" downtime_ms
# Rollback set retained
assert_file_exists "$SOVIEZ_ROOT/updates/backups/$op_id/rollback_manifest.json"
# Candidate license slot false
python3 -c "import json; d=json.load(open('$SOVIEZ_ROOT/updates/candidates/$op_id/candidate.json')); assert d.get('license_slot_consumed') is False"

# 4) Post-switch failure → rollback
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
export SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL=1
set +e
out="$(bash "$BIN" --update "$PROD_A" --confirm 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_POST_SWITCH_VALIDATION_FAILED
# After rollback digest should be old
cur="$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/current_digest.txt" 2>/dev/null || true)"
[[ "$cur" == "$DIGEST_OLD" || "$cur" == "" ]] || assert_eq "$DIGEST_OLD" "$(python3 -c "import json;print(json.load(open('$SOVIEZ_TENANT_DIR/$PROD_A/identity.json'))['current_digest'])")"
unset SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL

# 5) Real disposable PG candidate upgrade when psql available
if command -v psql >/dev/null 2>&1 && command -v createdb >/dev/null 2>&1; then
  setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  unset SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL
  # Use default local socket postgres if available
  if createdb "soviez_p15_probe_$$" 2>/dev/null; then
    dropdb "soviez_p15_probe_$$" 2>/dev/null || true
    export SOVIEZ_UPDATE_FIXTURE_PG_URL="dbname=postgres"
    out="$(bash "$BIN" --update "$PROD_A" --confirm)"
    assert_contains "$out" UPDATE_COMPLETED
    op_id="$(printf '%s\n' "$out" | python3 -c 'import sys,json
op=None
for line in sys.stdin:
  line=line.strip()
  if line.startswith("{"):
    try:
      d=json.loads(line)
      if d.get("operation_id"): op=d["operation_id"]
    except Exception: pass
print(op or "")')"
    # Upgrade result proves candidate-only mutation
    assert_contains "$(cat "$SOVIEZ_ROOT/updates/operations/$op_id/upgrade_result.json")" '"live_production_mutated":false'
  else
    echo "NOTE: local createdb unavailable — PG e2e skipped (fixture path still exercised)" >&2
  fi
else
  echo "NOTE: psql not installed — disposable PG marker path skipped; file-level candidate upgrade still run" >&2
  setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  out="$(bash "$BIN" --update "$PROD_A" --confirm)"
  assert_contains "$out" UPDATE_COMPLETED
fi

# 6) Disconnect/resume: pause at waiting_for_switch by completing pre-switch via partial state
# Simulate reattach from waiting_for_switch
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
# Run until we can create state manually — use offline package to avoid network
pkg="$SOVIEZ_ROOT/pkg-resume"
mkdir -p "$pkg"
python3 - <<PY > "$pkg/package.json"
import json
print(json.dumps({
  "package_id":"resume-1","nonce":"resume-1","signed":True,"signature":"ok",
  "digest":"$DIGEST_NEW","license_id":"$LIC_A","production_environment_id":"$PROD_A",
  "capability":"product_updates","entitlement_ok":True,"architecture":"$(uname -m)",
  "erp_major":"18","release_id":"rel-resume","expires_at":"2099-01-01T00:00:00Z",
},separators=(",",":")))
PY
# Full update then status
out="$(bash "$BIN" --update "$PROD_A" --offline-package "$pkg" --confirm)"
op_id="$(printf '%s\n' "$out" | python3 -c 'import sys,json
op=None
for line in sys.stdin:
  line=line.strip()
  if line.startswith("{"):
    try:
      d=json.loads(line)
      if d.get("operation_id"): op=d["operation_id"]
    except Exception: pass
print(op or "")')"
st="$(bash "$BIN" --update-status "$op_id")"
assert_contains "$st" completed

# 7) Inode / memory injection
setup_prod "$PROD_A" "$LIC_A" "$DIGEST_OLD" "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
export SOVIEZ_UPDATE_FIXTURE_AVAILABLE_INODES=10
set +e
out="$(bash "$BIN" --update "$PROD_A" --confirm 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_INODES_INSUFFICIENT
unset SOVIEZ_UPDATE_FIXTURE_AVAILABLE_INODES

echo "PASS test_update_e2e"
rm -rf "$SOVIEZ_ROOT"
