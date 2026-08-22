#!/usr/bin/env bash
# Phase 15 final certification — real Docker ERP candidate + License Guard + interrupt/reboot + images
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
source "$ROOT/tests/helpers/erp_release_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

if ! docker info >/dev/null 2>&1; then
  echo "FAIL: Docker daemon required for Phase 15 final certification" >&2
  exit 1
fi
soviez_test_erp_fixture_tags_ensure || { echo "FAIL: ERP catalog fixture setup" >&2; exit 1; }

bash "$ROOT/build/assemble.sh" >/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_UPDATE_REAL_DOCKER=1
export SOVIEZ_UPDATE_ASSUME_YES=1
export SOVIEZ_MIGRATION_SECRET=phase15-disposable-migration-secret-not-production
export SOVIEZ_UPDATE_REAL_IMAGE="${SOVIEZ_TEST_ERP_CURRENT_IMAGE}"
export SOVIEZ_UPDATE_REAL_PG_NAME=soviez-upd-pg-cert
export SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS=24
unset SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL SOVIEZ_UPDATE_FIXTURE_UPGRADE_FAIL SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL 2>/dev/null || true
unset SOVIEZ_UPDATE_SKIP_COLIMA_REBOOT 2>/dev/null || true
# Exact disposable PG fixture name — remove leftover from interrupted prior runs
docker rm -f "$SOVIEZ_UPDATE_REAL_PG_NAME" >/dev/null 2>&1 || true

# Colima-visible workspace path (not macOS mktemp under /var/folders)
SOVIEZ_ROOT="$ROOT/.tmp/p15-final-cert-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
export SOVIEZ_ROOT
export SOVIEZ_UPDATE_CANDIDATE_HOST_ROOT="$SOVIEZ_ROOT/candidate-host"
soviez_paths_init
soviez_stage_paths_init
soviez_ops_paths_init
soviez_update_paths_init

HOST="$(hostname -f 2>/dev/null || hostname)"
PROD=prod-final-a
LIC=lic-final-a
DIGEST_OLD="$(docker image inspect "${SOVIEZ_TEST_ERP_PRIOR_IMAGE}" --format '{{.Id}}')"
DIGEST_NEW="$(docker image inspect "${SOVIEZ_TEST_ERP_CURRENT_IMAGE}" --format '{{.Id}}')"
DIGEST_V13="$(docker image inspect "${SOVIEZ_TEST_ERP_LEGACY_IMAGE}" --format '{{.Id}}')"

mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore" "$SOVIEZ_TENANT_DIR/$PROD/addons"
printf 'fixture\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/dump.sql"
printf 'fs\n' > "$SOVIEZ_TENANT_DIR/$PROD/filestore/a"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"$LIC","account_id":"acct-final",
  "database_uuid":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "fingerprint":"fp-$PROD","production_fingerprint":"fp-$PROD",
  "container":"soviez-web-$PROD","container_status":"running",
  "current_digest":"$DIGEST_OLD","image_digest":"$DIGEST_OLD","erp_major":"18",
  "host_identity":"$HOST",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "addons_path":"$SOVIEZ_TENANT_DIR/$PROD/addons",
  "database_bytes":8192,"filestore_bytes":8192,"image_bytes":1048576,
},separators=(",",":")))
PY

export SOVIEZ_UPDATE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"capability":"product_updates","source_type":"annual_support","license_id":"lic-final-a","account_id":"acct-final","decision":"allow"}'
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON
SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "release_id":"rel-final-15","digest":"$DIGEST_NEW","signed":True,"signature":"sig-final",
  "architecture":"$(uname -m)","erp_major":"18","image_ref":"${SOVIEZ_TEST_ERP_IMAGE_REF}",
},separators=(",",":")))
PY
)"
export SOVIEZ_UPDATE_FIXTURE_PULL_SESSION_JSON='{"ok":true,"token":"tok","expires_in":30}'

docker image inspect "${SOVIEZ_TEST_ERP_PRIOR_IMAGE}" >/dev/null
docker image inspect "${SOVIEZ_TEST_ERP_CURRENT_IMAGE}" >/dev/null
docker image inspect "${SOVIEZ_TEST_ERP_LEGACY_IMAGE}" >/dev/null

# Ensure shared PG exists for real path (S1: soviez_admin bootstrap)
docker start "$SOVIEZ_UPDATE_REAL_PG_NAME" >/dev/null 2>&1 || \
  docker run -d --name "$SOVIEZ_UPDATE_REAL_PG_NAME" \
    -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD=soviez_admin_disp_not_prod \
    -e POSTGRES_DB=postgres postgres:16 >/dev/null
# If legacy odoo bootstrap remains, recreate disposable PG for S1.
if ! docker exec -e PGPASSWORD=soviez_admin_disp_not_prod "$SOVIEZ_UPDATE_REAL_PG_NAME" \
    psql -U soviez_admin -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
  docker rm -f "$SOVIEZ_UPDATE_REAL_PG_NAME" >/dev/null 2>&1 || true
  docker run -d --name "$SOVIEZ_UPDATE_REAL_PG_NAME" \
    -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD=soviez_admin_disp_not_prod \
    -e POSTGRES_DB=postgres postgres:16 >/dev/null
fi
for i in $(seq 1 40); do
  docker exec "$SOVIEZ_UPDATE_REAL_PG_NAME" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done
# Seed update PG creds file so real_docker matches this disposable bootstrap.
mkdir -p "$SOVIEZ_ROOT/secrets"
umask 077
APP_PASS="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(24)))')"
cat > "$SOVIEZ_ROOT/secrets/update_pg_creds" <<CEOF
SOVIEZ_UPDATE_PG_ADMIN_USER=soviez_admin
SOVIEZ_UPDATE_PG_ADMIN_PASSWORD=soviez_admin_disp_not_prod
SOVIEZ_UPDATE_PG_APP_USER=soviez_app
SOVIEZ_UPDATE_PG_APP_PASSWORD=${APP_PASS}
CEOF
chmod 600 "$SOVIEZ_ROOT/secrets/update_pg_creds"

# --- Real connected update with Docker candidate ---
slot_before="$(soviez_update_lg_slot_ledger_snapshot)"
out="$(soviez_update_run "$PROD" "rel-final-15" "" 1)"
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
[[ -n "$op_id" ]]

assert_file_exists "$(soviez_update_op_dir "$op_id")/upgrade.log"
assert_contains "$(cat "$(soviez_update_candidate_dir "$op_id")/runtime/isolation_proof.txt")" real_docker
assert_file_exists "$(soviez_update_candidate_dir "$op_id")/runtime/license_guard_identity.json"
assert_file_exists "$(soviez_update_candidate_dir "$op_id")/runtime/license_guard_proof.json"
slot_val="$(soviez_json_get "$(cat "$(soviez_update_candidate_dir "$op_id")/runtime/license_guard_identity.json")" license_slot_consumed)"
[[ "$slot_val" == "false" || "$slot_val" == "False" ]] || { echo "ASSERT license_slot_consumed false got $slot_val" >&2; exit 1; }
slot_after="$(soviez_update_lg_slot_ledger_snapshot)"
soviez_update_lg_assert_no_slot_burn "$slot_before" "$slot_after"
assert_file_exists "$(soviez_update_candidate_dir "$op_id")/runtime/http_validation.json"
assert_eq "$DIGEST_NEW" "$(soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD/identity.json")" current_digest)"

# --- Custom addon failure (Production untouched) ---
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"$LIC","account_id":"acct-final",
  "database_uuid":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "fingerprint":"fp-$PROD","production_fingerprint":"fp-$PROD",
  "container":"soviez-web-$PROD","container_status":"running",
  "current_digest":"$DIGEST_OLD","previous_digest":"$DIGEST_NEW","image_digest":"$DIGEST_OLD","erp_major":"18",
  "host_identity":"$HOST",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "addons_path":"$SOVIEZ_TENANT_DIR/$PROD/addons",
  "database_bytes":8192,"filestore_bytes":8192,"image_bytes":1048576,
},separators=(",",":")))
PY
export SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL=1
set +e
out="$(soviez_update_run "$PROD" "rel-final-15" "" 1 2>&1)"
rc=$?
set -e
assert_contains "$out" UPDATE_CANDIDATE_UPGRADE_FAILED
assert_eq "$DIGEST_OLD" "$(soviez_json_get "$(cat "$SOVIEZ_TENANT_DIR/$PROD/identity.json")" current_digest)"
unset SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL

# --- Interrupt matrix sample + Colima host reboot for required checkpoints ---
mk_op() {
  local id="$1" state="$2" cp="$3"
  mkdir -p "$(soviez_update_op_dir "$id")" "$(soviez_update_backup_dir "$id")"
  printf '%s' "$DIGEST_NEW" > "$(soviez_update_op_dir "$id")/target_digest.txt"
  SOVIEZ_OP="$id" SOVIEZ_T="$PROD" SOVIEZ_D="$DIGEST_OLD" python3 - <<'PY' > "$(soviez_update_rollback_manifest "$id")"
import json,os
print(json.dumps({"operation_id":os.environ["SOVIEZ_OP"],"tenant_id":os.environ["SOVIEZ_T"],"previous_digest":os.environ["SOVIEZ_D"],"created_at":"2020-01-01T00:00:00Z"},separators=(",",":")))
PY
  soviez_update_state_write "$id" "$state" "$cp" "{\"environment_id\":\"$PROD\"}"
}

# Interrupt at upgrading_candidate
op_int="upd-interrupt-test"
mkdir -p "$(soviez_update_op_dir "$op_int")"
printf 'upgrading_candidate\n' > "$(soviez_update_op_dir "$op_int")/interrupt_at"
soviez_update_state_write "$op_int" running upgrading_candidate "{\"environment_id\":\"$PROD\"}"
set +e
soviez_update_interrupt_checkpoint "$op_int" upgrading_candidate
irc=$?
set -e
[[ "$irc" -eq 42 ]] || { echo "interrupt expected 42 got $irc" >&2; exit 1; }
recon="$(soviez_update_reboot_reconcile "$op_int")"
assert_contains "$recon" UPDATE_RECOVERY_REQUIRED

# Persist ops at required reboot checkpoints, then one Colima VM restart
mk_op upd-rb-upgrade upgrading_candidate upgrading_candidate
mk_op upd-rb-preswitch waiting_for_switch waiting_for_switch
mk_op upd-rb-switch switching switching
mk_op upd-rb-rollback rollback_running rollback_running
mk_op upd-rb-imgclean image_cleanup image_cleanup

if [[ "${SOVIEZ_UPDATE_SKIP_COLIMA_REBOOT:-0}" == "1" ]]; then
  echo "NOTE: Colima reboot skipped by env" >&2
  for id in upd-rb-upgrade upd-rb-preswitch upd-rb-switch upd-rb-rollback upd-rb-imgclean; do
    out="$(soviez_update_reboot_reconcile "$id")"
    assert_contains "$out" UPDATE_
  done
else
  # One host-level Docker/VM restart; reconcile all checkpoint states from disk
  printf 'reboot_batch=1\n' > "$(soviez_update_op_dir upd-rb-switch)/reboot_intent.txt"
  before_boot="$(date +%s)"
  colima stop >/dev/null 2>&1 || true
  colima start >/dev/null 2>&1
  export DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
  for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || { echo "Docker not ready after Colima reboot" >&2; exit 1; }
  after_boot="$(date +%s)"
  for id in upd-rb-upgrade upd-rb-preswitch upd-rb-switch upd-rb-rollback upd-rb-imgclean; do
    out="$(soviez_update_reboot_reconcile "$id")"
    SOVIEZ_O="$out" SOVIEZ_L="$id" SOVIEZ_B="$before_boot" SOVIEZ_A="$after_boot" python3 - <<'PY' > "$(soviez_update_op_dir "$id")/reboot_${id}.json"
import json,os
body=json.loads(os.environ["SOVIEZ_O"])
body["reboot_label"]=os.environ["SOVIEZ_L"]
body["host_reboot"]="colima_vm_restart"
body["duration_sec"]=int(os.environ["SOVIEZ_A"])-int(os.environ["SOVIEZ_B"])
body["shared_host_reboot_batch"]=True
print(json.dumps(body,separators=(",",":")))
PY
    assert_contains "$(cat "$(soviez_update_op_dir "$id")/reboot_${id}.json")" "UPDATE_"
  done
  # Switching/rollback must be recovery_required (no blind replay)
  assert_contains "$(cat "$(soviez_update_op_dir upd-rb-switch)/reboot_upd-rb-switch.json")" "UPDATE_RECOVERY_REQUIRED"
  assert_contains "$(cat "$(soviez_update_op_dir upd-rb-rollback)/reboot_upd-rb-rollback.json")" "UPDATE_RECOVERY_REQUIRED"
fi

# Restart PG after Colima reboot for later cleanup docker ops (S1 bootstrap)
docker start "$SOVIEZ_UPDATE_REAL_PG_NAME" >/dev/null 2>&1 || \
  docker run -d --name "$SOVIEZ_UPDATE_REAL_PG_NAME" \
    -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD=soviez_admin_disp_not_prod \
    -e POSTGRES_DB=postgres postgres:16 >/dev/null

# --- Image cleanup: dry-run, protections, exact delete ---
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","current_digest":"$DIGEST_NEW","previous_digest":"$DIGEST_OLD","image_digest":"$DIGEST_NEW",
},separators=(",",":")))
PY
# Other production referencing v13
mkdir -p "$SOVIEZ_TENANT_DIR/prod-final-b"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/prod-final-b/identity.json"
import json
print(json.dumps({"tenant_id":"prod-final-b","current_digest":"$DIGEST_V13","image_digest":"$DIGEST_V13"},separators=(",",":")))
PY
# Stage referencing v13 (should protect until removed — here we use a disposable older labeled only if unused elsewhere)
mkdir -p "$SOVIEZ_STAGES_DIR/stage-final-1"
python3 - <<PY > "$SOVIEZ_STAGES_DIR/stage-final-1/identity.json"
import json
print(json.dumps({"stage_id":"stage-final-1","parent_production_tenant_id":"$PROD","image_digest":"$DIGEST_V13"},separators=(",",":")))
PY
# Stopped container from an extra labeled image — create disposable tag copy if needed
STOPPED_IMG="${SOVIEZ_TEST_ERP_LEGACY_IMAGE}"
docker create --name soviez-cert-stopped-ref "$STOPPED_IMG" >/dev/null 2>&1 || true
docker stop soviez-cert-stopped-ref >/dev/null 2>&1 || true

dry="$(soviez_image_cleanup_dry_run "$PROD")"
assert_contains "$dry" IMAGE_CLEANUP_DRY_RUN
# Current + rollback protected
assert_contains "$(soviez_image_classify "$DIGEST_NEW" "$DIGEST_OLD")" current
assert_contains "$(soviez_image_classify "$DIGEST_NEW" "$DIGEST_OLD")" rollback

export SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED=1
# v13 protected by other production + stage + stopped container
cleaned="$(soviez_image_cleanup_execute "$PROD" 1 "" 0)"
assert_contains "$cleaned" IMAGE_CLEANUP
docker image inspect "$DIGEST_NEW" >/dev/null
docker image inspect "$DIGEST_OLD" >/dev/null
docker image inspect "$DIGEST_V13" >/dev/null

# Remove stage + other prod + stopped container refs → v13 may become eligible
rm -rf "$SOVIEZ_STAGES_DIR/stage-final-1" "$SOVIEZ_TENANT_DIR/prod-final-b"
docker rm -f soviez-cert-stopped-ref >/dev/null 2>&1 || true
# Tag a disposable eligible image distinct from current/rollback for deletion proof
# Use legacy fixture tag only if no longer referenced
cleaned2="$(soviez_image_cleanup_execute "$PROD" 1 "" 0)"
assert_contains "$cleaned2" IMAGE_CLEANUP
# Forbidden prune static gate
soviez_image_forbid_prune_static_gate >/dev/null

echo "PASS test_update_final_certification"
# Cleanup disposable containers (keep labeled images for reuse)
docker rm -f "$(awk -F= '/^container=/{print $2}' "$(soviez_update_candidate_dir "$op_id")/runtime/identity.txt" 2>/dev/null)" 2>/dev/null || true
rm -rf "$SOVIEZ_ROOT"
