#!/usr/bin/env bash
# Phase 19 — unit: plan, manifest, targeting, backup gate, chunks, freeze timeout,
# abort, token flags, stage select, config sanitize, resume
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
export SOVIEZ_MIG_TRANSFER_LOCAL=1 SOVIEZ_MIG_FREEZE_FIXTURE=1 SOVIEZ_MIG_FORCE_FIXTURE_DB=1
unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_REAL_MTLS SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES \
  SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER \
  SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB \
  SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT SOVIEZ_MIG_REAL_ERP_STAGING 2>/dev/null || true
export SOVIEZ_MIG_FORCE_FIXTURE_ERP=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p19-unit.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_migration_paths_init
soviez_device_ensure_keys

PROD="prod-p19-a"
LIC="lic-p19-a"
PROD_DOMAIN="p19.example.test"
DIGEST="sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

export SOVIEZ_MIG_DNS_ZONE_DIR="$SOVIEZ_ROOT/dns_zone"
mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
export SOVIEZ_MIG_FIXTURE_OS_ID="ubuntu:22.04" SOVIEZ_MIG_FIXTURE_ARCH="amd64"
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200 * 1024 * 1024 * 1024)) SOVIEZ_MIG_FIXTURE_INODES=5000000
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id":"$PROD","environment_id":"$PROD","license_id":"$LIC",
  "database_uuid":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","image_digest":"$DIGEST",
  "domain":"$PROD_DOMAIN","erp_version":"18.0","postgresql_major":"16",
}))
PY
)"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1048576,"filestore_bytes":524288,"addon_bytes":1024,"configuration_bytes":1024,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2000000,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$PROD_DOMAIN\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[{"stage_id":"stage-p19-1","parent_production_id":"'"$PROD"'","status":"active","expired":false}]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-p19-1","classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":100,"restore_tested":true,"status":"VERIFIED"}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'
export SOVIEZ_MIG_FIXTURE_HEALTH_JSON='{"source_maintenance_enabled":false,"dns_changed":false,"data_transfer_started":false,"disruption_detected":false}'

pass_count=0
ok() { echo "OK: $1"; pass_count=$((pass_count+1)); }
assert_eq() { [[ "$1" == "$2" ]] || { echo "FAIL: $3 (got '$1' want '$2')" >&2; exit 1; }; ok "$3"; }

# --- Phase 17/18 baseline ---
DISC="$(soviez_migration_discover_run "$PROD")"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"
BOOT_ID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC_FP="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST_FP="$(soviez_json_get "$BOOT" public_fingerprint)"
PAIR="$(soviez_migration_pair_run "$PROD" "$CODE" "$SRC_FP" "$DST_FP" "$LIC" "$PROD" "$BOOT_ID" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"

# Minimal routing PASS plan (fixture) — avoid full DNS/TLS path for unit speed
ROUTING_ID="$(soviez_migration_new_id rplan)"
mkdir -p "$(soviez_migration_routing_plan_dir "$ROUTING_ID")"
python3 - <<PY
import json, datetime
p="$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"
doc={
  "plan_id":"$ROUTING_ID","migration_pair_id":"$PAIR_ID","result":"PASS",
  "cutover_authorized":False,"migration_token_consumed":False,
  "issued_at":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at":(datetime.datetime.utcnow()+datetime.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(p,"w").write(json.dumps(doc, separators=(",", ":")))
PY
soviez_migration_sign_object_file "$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"

# Phase 17/18 assert_no_transfer still dies on ALLOW_TRANSFER
if ( SOVIEZ_MIG_ALLOW_TRANSFER=1 soviez_migration_assert_no_transfer ) 2>/dev/null; then
  echo "FAIL: assert_no_transfer should die"; exit 1
fi
ok "assert_no_transfer still blocks ALLOW_TRANSFER"

# Phase 19 cutover/token always blocked
if ( SOVIEZ_MIG_ALLOW_CUTOVER=1 soviez_migration_assert_no_cutover_or_token ) 2>/dev/null; then
  echo "FAIL: cutover"; exit 1
fi
ok "assert_no_cutover_or_token blocks cutover"
if ( SOVIEZ_MIG_ALLOW_TOKEN_CONSUME=1 soviez_migration_assert_no_cutover_or_token ) 2>/dev/null; then
  echo "FAIL: token"; exit 1
fi
ok "assert_no_cutover_or_token blocks token consume"

# Targeting
soviez_migration_transfer_require_routing "$PAIR_ID" "$ROUTING_ID"
ok "targeting exact pair+routing"

# Backup gate
PIN="$(soviez_migration_transfer_backup_gate "$PAIR_ID" "")"
assert_eq "$(soviez_json_get "$PIN" pinned)" "True" "backup pinned"
[[ -f "$(soviez_migration_transfer_op_dir "pin-$PAIR_ID")/backup_pin.json" ]] || { echo "FAIL pin file"; exit 1; }
ok "backup pin file exists"

# Old backup blocked
if ( SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","latest_verified_age_seconds":999999,"status":"VERIFIED"}' \
     soviez_migration_transfer_backup_gate "$PAIR_ID" "" ) 2>/dev/null; then
  echo "FAIL: old backup should block"; exit 1
fi
ok "old backup blocked"

# Transfer plan + manifest
PLAN="$(soviez_migration_transfer_plan_run "$PAIR_ID" "$ROUTING_ID")"
PLAN_ID="$(soviez_json_get "$PLAN" transfer_plan_id)"
assert_eq "$(soviez_json_get "$PLAN" migration_token_reserved)" "False" "plan token reserved false"
assert_eq "$(soviez_json_get "$PLAN" migration_token_consumed)" "False" "plan token consumed false"
assert_eq "$(soviez_json_get "$PLAN" destination_production_activated)" "False" "plan dest not activated"
assert_eq "$(soviez_json_get "$PLAN" traffic_cutover_started)" "False" "plan cutover false"
soviez_migration_verify_object_signature "$(soviez_migration_transfer_plan_dir "$PLAN_ID")/object.json" || { echo "FAIL plan sig"; exit 1; }
ok "transfer plan signed"

MANIFEST="$(soviez_migration_transfer_manifest_create "$PLAN" "$(soviez_json_get "$PLAN" operation_id)")"
MID="$(soviez_json_get "$MANIFEST" manifest_id)"
assert_eq "$(soviez_json_get "$MANIFEST" migration_token_reserved)" "False" "manifest token reserved false"
assert_eq "$(soviez_json_get "$MANIFEST" traffic_cutover_started)" "False" "manifest cutover false"
soviez_migration_verify_object_signature "$(soviez_migration_transfer_manifest_dir "$MID")/object.json" || { echo "FAIL man sig"; exit 1; }
ok "transfer manifest signed"

# Chunks
OP_CHUNK="$(soviez_migration_new_id chunkop)"
soviez_migration_chunk_registry_init "$OP_CHUNK" "$MID"
SRC_FILE="$SOVIEZ_ROOT/payload.bin"
python3 -c "open('$SRC_FILE','wb').write(b'x'*150000)"
# Use small chunk size for unit speed
soviez_migration_chunk_plan_file "$OP_CHUNK" "obj-a" "database" "$SRC_FILE" 65536 >/dev/null
soviez_migration_channel_init "$PAIR_ID" "$OP_CHUNK" "$MID" >/dev/null
soviez_migration_chunk_transfer_all "$OP_CHUNK" "fast" >/dev/null
ASM="$SOVIEZ_ROOT/assembled.bin"
soviez_migration_chunk_assemble_object "$OP_CHUNK" "obj-a" "$ASM" >/dev/null
cmp -s "$SRC_FILE" "$ASM" || { echo "FAIL assemble mismatch"; exit 1; }
ok "chunk plan/verify/assemble"

# Resume from registry (idempotent when chunks already verified)
soviez_migration_transfer_state_write "$OP_CHUNK" "{\"operation_id\":\"$OP_CHUNK\",\"current_state\":\"paused\",\"migration_pair_id\":\"$PAIR_ID\",\"manifest_id\":\"$MID\"}" >/dev/null
soviez_migration_transfer_resume_from_registry "$OP_CHUNK" >/dev/null
ok "resume from chunk registry"

# Config sanitize
SAN="$(soviez_migration_config_sanitize '{"settings":{"db.host":"localhost","smtp.password":"secret","mail.enabled":true,"ok_flag":"1"}}')"
SETTINGS="$(soviez_json_get "$SAN" settings)"
echo "$SETTINGS" | grep -q 'smtp.password' && { echo "FAIL secret leaked in settings"; exit 1; } || true
REMOVED="$(soviez_json_get "$SAN" removed_secret_keys)"
echo "$REMOVED" | grep -q smtp || { echo "FAIL secret not removed"; exit 1; }
ok "config sanitize strips secrets"
python3 - <<PY
import json, os
s=json.loads('''$SETTINGS''')
assert s.get("mail.enabled") is False, s
print("OK: mail neutralized")
PY
pass_count=$((pass_count+1))

# Stage select / mandatory
soviez_migration_stage_mark_mandatory "$PAIR_ID" "stage-p19-1" >/dev/null
PAIR_OBJ="$(cat "$(soviez_migration_pair_dir "$PAIR_ID")/object.json")"
echo "$PAIR_OBJ" | grep -q stage-p19-1 || [[ -f "$(soviez_migration_stage_selection_dir "$PAIR_ID")/flags.json" ]] || { echo "FAIL stage flags"; exit 1; }
ok "stage mark mandatory"
# Clear selection before full transfer_start (stage-p19-1 is not in discovery inventory)
soviez_migration_stage_select "$PAIR_ID" "stage-p19-1" unselect >/dev/null 2>&1 || true
if [[ -f "$(soviez_migration_pair_dir "$PAIR_ID")/object.json" ]]; then
  SOVIEZ_P="$(soviez_migration_pair_dir "$PAIR_ID")/object.json" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["selected_stage_ids"]=[]
d["stage_flags"]={}
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$(soviez_migration_pair_dir "$PAIR_ID")/object.json" 2>/dev/null || true
fi

# Freeze timeout reconcile
OP_FZ="$(soviez_migration_new_id freeze)"
export SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS=1
soviez_migration_freeze_start "$PAIR_ID" "$OP_FZ" >/dev/null
# Force expired
python3 - <<PY
import json
p="$(soviez_migration_freeze_state_path "$OP_FZ")"
d=json.load(open(p))
d["expires_at"]="2000-01-01T00:00:00Z"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
REL="$(soviez_migration_freeze_reconcile "$PAIR_ID" "$OP_FZ")"
assert_eq "$(soviez_json_get "$REL" released)" "True" "freeze released on timeout reconcile"
[[ -f "$(soviez_migration_freeze_dir "$OP_FZ")/timed_out" ]] || { echo "FAIL timed_out marker"; exit 1; }
ok "freeze timeout auto-release"
unset SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS
export SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS=900

# Abort preserves staging + token flags
set +e
START="$(soviez_migration_transfer_start "$PAIR_ID" "$ROUTING_ID" 2>/tmp/p19-unit-start.err)"
start_rc=$?
set -e
if [[ "$start_rc" -ne 0 ]]; then
  echo "FAIL transfer_start rc=$start_rc" >&2
  cat /tmp/p19-unit-start.err >&2 || true
  exit "$start_rc"
fi
OP_ID="$(soviez_json_get "$START" operation_id)"
# Tolerate Python True/False vs JSON true/false
tok_r="$(soviez_json_get "$START" migration_token_reserved)"
tok_c="$(soviez_json_get "$START" migration_token_consumed)"
[[ "$tok_r" == "False" || "$tok_r" == "false" ]] || { echo "FAIL token reserved"; exit 1; }
ok "start token reserved false"
[[ "$tok_c" == "False" || "$tok_c" == "false" ]] || { echo "FAIL token consumed"; exit 1; }
ok "start token consumed false"
assert_eq "$(soviez_json_get "$START" destination_production_activated)" "False" "start dest inactive"
assert_eq "$(soviez_json_get "$START" traffic_cutover_started)" "False" "start cutover false"
STAGING="$(soviez_json_get "$START" destination_staging_id)"
[[ -n "$STAGING" ]] || { echo "FAIL no staging"; exit 1; }
ABORT="$(soviez_migration_transfer_abort "$OP_ID")"
tok_c2="$(soviez_json_get "$ABORT" migration_token_consumed)"
[[ "$tok_c2" == "False" || "$tok_c2" == "false" ]] || { echo "FAIL abort token"; exit 1; }
ok "abort token false"
fr="$(soviez_json_get "$ABORT" source_write_freeze)"
[[ "$fr" == "False" || "$fr" == "false" ]] || { echo "FAIL abort freeze"; exit 1; }
ok "abort freeze released"
# staging dir preserved by default
[[ -d "$(soviez_migration_staging_dir "$STAGING")" ]] || { echo "FAIL staging deleted on abort"; exit 1; }
ok "abort preserves staging"

# phase19 transfer allowed requires authorized op
if ( soviez_migration_assert_phase19_transfer_allowed "$PAIR_ID" "evil_op" ) 2>/dev/null; then
  echo "FAIL: evil op allowed"; exit 1
fi
ok "phase19 transfer rejects unauthorized op"
soviez_migration_assert_phase19_transfer_allowed "$PAIR_ID" "migration_transfer_plan"
ok "phase19 transfer allows plan op"

echo "phase19 unit: PASS ($pass_count assertions)"
