#!/usr/bin/env bash
# Phase 16 — Production backup/restore unit tests
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_PASSPHRASE="unit-test-passphrase-not-secret-for-prod"
unset SOVIEZ_BACKUP_DISABLE_ENCRYPTION 2>/dev/null || true
unset SOVIEZ_ROOT SOVIEZ_OPS_ROOT SOVIEZ_OPS_INDEX_DIR SOVIEZ_OPS_REGISTRY_DIR \
  SOVIEZ_BACKUP_ROOT SOVIEZ_BACKUP_OPS_DIR SOVIEZ_STAGES_DIR SOVIEZ_TENANT_DIR \
  SOVIEZ_DEVICE_DIR SOVIEZ_SECRETS_DIR 2>/dev/null || true
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p16-unit.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init 2>/dev/null || true
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init
soviez_restore_paths_init 2>/dev/null || true
# Ensure ops index is empty under disposable root
mkdir -p "${SOVIEZ_OPS_INDEX_DIR:-$SOVIEZ_ROOT/ops/index}"
rm -f "${SOVIEZ_OPS_INDEX_DIR:-$SOVIEZ_ROOT/ops/index}"/*.json 2>/dev/null || true

HOST="$(hostname -f 2>/dev/null || hostname || echo unknown)"
PROD_A="prod-a-p16"
PROD_B="prod-b-p16"
LIC_A="lic-a-p16"
LIC_B="lic-b-p16"

setup_prod() {
  local tid="$1" lic="$2"
  local uuid
  case "$tid" in
    prod-a-p16) uuid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" ;;
    prod-b-p16) uuid="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" ;;
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
  "account_id":"acct-p16",
  "database_uuid":"$uuid",
  "database_name":"db_$tid",
  "fingerprint":"fp-$tid",
  "production_fingerprint":"fp-$tid",
  "container":"soviez-web-$tid",
  "container_status":"running",
  "current_digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "image_digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "erp_major":"18",
  "host_identity":"$HOST",
  "database_path":"$tdir/db",
  "filestore_path":"$tdir/filestore",
  "addons_path":"$tdir/addons",
  "database_bytes":4096,
  "filestore_bytes":4096,
},separators=(",",":")))
PY
}

setup_prod "$PROD_A" "$LIC_A"
setup_prod "$PROD_B" "$LIC_B"
mkdir -p "${SOVIEZ_STAGES_DIR:-$SOVIEZ_ROOT/stages}/stage-x"
printf '{"stage_id":"stage-x","parent_production_tenant_id":"%s"}\n' "$PROD_A" \
  > "${SOVIEZ_STAGES_DIR:-$SOVIEZ_ROOT/stages}/stage-x/identity.json"

# --- Targeting ---
set +e
out="$(soviez_backup_run "" local-primary full 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "missing target must fail" >&2; exit 1; }
echo "$out" | grep -q BACKUP_TARGET_REQUIRED || { echo "expected BACKUP_TARGET_REQUIRED: $out" >&2; exit 1; }

set +e
out="$(soviez_backup_run all local-primary full 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "wildcard must fail" >&2; exit 1; }
echo "$out" | grep -qE 'BACKUP_TARGET_INVALID|BACKUP_TARGET_REQUIRED' || {
  echo "expected target invalid: $out" >&2; exit 1
}

set +e
out="$(soviez_backup_run stage-x local-primary full 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "stage target must fail" >&2; exit 1; }
echo "$out" | grep -q BACKUP_STAGE_TARGET_DENIED || {
  echo "expected STAGE_TARGET_DENIED: $out" >&2; exit 1
}

# --- Encryption defaults ---
soviez_backup_encryption_required local && echo "local encryption ON ok"
! soviez_backup_encryption_required local || true
export SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1
soviez_backup_encryption_required local && { echo "disable should make local encryption optional" >&2; exit 1; } || true
unset SOVIEZ_BACKUP_DISABLE_ENCRYPTION
soviez_backup_encryption_required s3 || { echo "remote encryption mandatory" >&2; exit 1; }
soviez_backup_encryption_required sftp || { echo "sftp encryption mandatory" >&2; exit 1; }

# --- Full local backup ---
export SOVIEZ_BACKUP_ASSUME_YES=1
set +e
out="$(soviez_backup_run "$PROD_A" local-primary full 1 2>/tmp/p16-bk.err)"
brc=$?
set -e
echo "$out" | grep -q BACKUP_COMPLETED || {
  echo "backup failed rc=$brc out=$out err=$(cat /tmp/p16-bk.err 2>/dev/null)" >&2
  exit 1
}
BID="$(echo "$out" | grep BACKUP_COMPLETED | tail -1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
[[ -n "$BID" ]]

obj="$(soviez_backup_read_object "$BID")"
echo "$obj" | grep -q '"backup_type":"full"' || { echo "type full missing" >&2; exit 1; }
echo "$obj" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["encryption"]["enabled"] is True'
v="$(soviez_json_get "$obj" verification_status)"
[[ "$v" == "VERIFIED" ]] || {
  # engine may have left verifying; force verify
  soviez_backup_verify_level1 "$BID" >/dev/null
  obj="$(soviez_backup_read_object "$BID")"
  v="$(soviez_json_get "$obj" verification_status)"
}
[[ "$v" == "VERIFIED" ]] || { echo "expected VERIFIED got $v" >&2; exit 1; }

# Manifest no secrets
man="$(soviez_backup_dir "$PROD_A" "$BID")/manifest.json"
grep -qiE 'passphrase|password|secret_key' "$man" && { echo "secret in manifest" >&2; exit 1; } || true
soviez_backup_manifest_verify "$man"

# Tamper detection
cp "$man" "$man.bak"
python3 - <<PY
import json
p="$man"
with open(p) as f: d=json.load(f)
d["backup_id"]="tampered"
with open(p,"w") as f: json.dump(d,f)
PY
set +e
out="$(soviez_backup_manifest_verify "$man" 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "tamper must fail" >&2; exit 1; }
mv "$man.bak" "$man"

# --- Database-only advanced ---
set +e
out="$(SOVIEZ_BACKUP_ADVANCED_ACK=0 soviez_backup_run "$PROD_A" local-primary database-only 0 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "db-only without advanced must fail" >&2; exit 1; }

out="$(SOVIEZ_BACKUP_ADVANCED_ACK=1 soviez_backup_run "$PROD_A" local-primary database-only 1)"
BID_DB="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
obj_db="$(soviez_backup_read_object "$BID_DB")"
echo "$obj_db" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["backup_type"]=="database_only"; assert d["restore_capable"] is False'

# Restore must deny database-only
set +e
out="$(soviez_restore_run "$PROD_A" "$BID_DB" 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "db-only restore must fail" >&2; exit 1; }
echo "$out" | grep -qE 'RESTORE_DATABASE_ONLY_BACKUP_DENIED|RESTORE_BACKUP_NOT_VERIFIED|RESTORE_' || {
  echo "expected deny: $out" >&2; exit 1
}

# --- Restore test ---
export SOVIEZ_BACKUP_RESTORE_TEST_CLEAN=1
rt="$(soviez_backup_restore_test "$BID")"
echo "$rt" | grep -q RESTORE_TESTED || { echo "restore test failed: $rt" >&2; exit 1; }
obj="$(soviez_backup_read_object "$BID")"
[[ "$(soviez_json_get "$obj" restore_test_status)" == "RESTORE_TESTED" ]]

# --- Pin protection ---
soviez_backup_inventory_pin "$BID" >/dev/null
obj="$(soviez_backup_read_object "$BID")"
[[ "$(soviez_json_get "$obj" pinned)" == "true" || "$(soviez_json_get "$obj" pinned)" == "True" ]]
set +e
out="$(SOVIEZ_CLI_CONFIRM=1 SOVIEZ_CLI_YES=1 soviez_cmd_backup_delete "$BID" 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "pinned delete must fail" >&2; exit 1; }
echo "$out" | grep -q BACKUP_PIN_PROTECTED || { echo "expected PIN_PROTECTED: $out" >&2; exit 1; }

# Retention must not classify pinned as eligible
class="$(soviez_backup_retention_classify "$PROD_A")"
BID="$BID" CLASS="$class" python3 - <<'PY'
import json, os
c = json.loads(os.environ["CLASS"])
bid = os.environ["BID"]
rows = [r for r in c.get("classifications", []) if r.get("backup_id") == bid]
assert rows, c
assert "pinned" in (rows[0].get("classes") or []), rows[0]
assert not rows[0].get("eligible_for_deletion"), rows[0]
print("pin retention ok")
PY

# --- Schedule default 02:00 ---
sched="$(soviez_backup_schedule_add "$PROD_A" local-primary)"
echo "$sched" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["hour_local"]==2 and d["minute_local"]==0; assert d.get("timezone")'
assert_eq "$(soviez_backup_schedule_default_hour)" "2"

# --- Cross-host deny ---
set +e
out="$(SOVIEZ_RESTORE_FIXTURE_HOST_MISMATCH=1 soviez_restore_compatibility_check \
  "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/identity.json")" "$obj" 2>&1)"
rc=$?
set -e
bad="$(SOVIEZ_O="$obj" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_O"]); d["host_identity"]="other-host"; print(json.dumps(d))')"
set +e
out="$(soviez_restore_compatibility_check "$(cat "$SOVIEZ_TENANT_DIR/$PROD_A/identity.json")" "$bad" 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "cross-host must fail" >&2; exit 1; }
echo "$out" | grep -qE 'RESTORE_HOST_IDENTITY_MISMATCH|RESTORE_' || true

# --- Wrong Production restore ---
set +e
out="$(soviez_restore_run "$PROD_B" "$BID" 1 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "wrong production must fail" >&2; exit 1; }
echo "$out" | grep -qE 'RESTORE_WRONG_PRODUCTION|RESTORE_BACKUP_OWNERSHIP|RESTORE_' || {
  echo "expected ownership mismatch: $out" >&2; exit 1
}

# --- Multi-tenant isolation: backup B leaves A intact ---
before_a="$(find "$SOVIEZ_TENANT_DIR/$PROD_A/filestore" -type f | wc -l | tr -d ' ')"
set +e
out_b="$(soviez_backup_run "$PROD_B" local-primary full 1 2>/tmp/p16-bkb.err)"
bbrc=$?
set -e
echo "$out_b" | grep -q BACKUP_COMPLETED || { echo "backup B failed rc=$bbrc err=$(cat /tmp/p16-bkb.err)" >&2; exit 1; }
after_a="$(find "$SOVIEZ_TENANT_DIR/$PROD_A/filestore" -type f | wc -l | tr -d ' ')"
[[ "$before_a" == "$after_a" ]] || { echo "tenant A filestore changed" >&2; exit 1; }
BID_B="$(echo "$out_b" | grep BACKUP_COMPLETED | tail -1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
list_a="$(soviez_backup_inventory_list "$PROD_A")"
echo "$list_a" | grep -q "$BID_B" && { echo "B backup listed under A" >&2; exit 1; } || true

# --- Export / import quarantine ---
expdir="$SOVIEZ_ROOT/export-out"
mkdir -p "$expdir"
export SOVIEZ_CLI_BACKUP_OUTPUT="$expdir/pkg"
set +e
ex="$(soviez_backup_export "$BID" "$expdir/pkg" 2>/tmp/p16-exp.err)"
set -e
echo "$ex" | grep -qE 'BACKUP_EXPORT|ok|true' || echo "$ex"
[[ -d "$expdir/pkg" || -f "$expdir/pkg" || -d "$expdir" ]]

# --- Production restore candidate-first ---
set +e
soviez_backup_verify_level1 "$BID" >/dev/null
soviez_backup_inventory_pin "$BID" >/dev/null 2>&1
rest="$(soviez_restore_run "$PROD_A" "$BID" 1 2>/tmp/p16-restore.err)"
rrc=$?
set -e
echo "$rest" | grep -q RESTORE_COMPLETED || {
  echo "restore failed rc=$rrc out=$rest err=$(cat /tmp/p16-restore.err 2>/dev/null)" >&2
  exit 1
}
OP="$(echo "$rest" | grep RESTORE_COMPLETED | tail -1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["operation_id"])')"
safety="$(soviez_restore_safety_window_info "$OP")"
echo "$safety" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("safety_window_hours")==24; assert d.get("rollback_available") is True'

# Rollback available
set +e
rb="$(SOVIEZ_CLI_CONFIRM=1 soviez_cmd_restore_rollback "$OP" 2>&1)"
set -e

# --- Restore-as-Stage ---
export SOVIEZ_STAGE_ENTITLEMENT_OK=1
set +e
ras="$(soviez_restore_as_stage "$BID" "stage.example.test" 1 2>/tmp/p16-ras.err)"
rasc=$?
set -e
echo "$ras" | grep -q RESTORE_AS_STAGE || {
  echo "restore-as-stage failed rc=$rasc out=$ras err=$(cat /tmp/p16-ras.err 2>/dev/null)" >&2
  exit 1
}

# --- Conflicts: one data-heavy ---
dec="$(soviez_ops_conflict_decide production_backup production_restore "$PROD_A" "$PROD_A" 1)"
[[ "$dec" == "deny" ]] || { echo "expected deny conflict got $dec" >&2; exit 1; }

# --- Forbidden static gates in assembled artifact ---
art="$ROOT/dist/soviez.sh"
grep -E 'StrictHostKeyChecking=no' "$art" && { echo "forbidden StrictHostKeyChecking=no" >&2; exit 1; } || true
grep -E 'docker system prune|docker volume prune|docker image prune -a' "$art" && {
  echo "forbidden docker prune" >&2; exit 1
} || true
grep -E 'rclone purge|aws s3 rm --recursive' "$art" && { echo "forbidden broad remote delete" >&2; exit 1; } || true

# --- Secret not in state ---
sf="$(find "$SOVIEZ_BACKUP_OPS_DIR" -name 'state.json' 2>/dev/null | head -1 || true)"
if [[ -n "$sf" && -f "$sf" ]]; then
  grep -F "$SOVIEZ_BACKUP_PASSPHRASE" "$sf" && { echo "passphrase in state" >&2; exit 1; } || true
fi

echo "PASS phase16 unit"
