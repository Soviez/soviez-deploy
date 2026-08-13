#!/usr/bin/env bash
# Phase 19 — authoritative real mTLS + PG + freeze + ERP staging + Stage E2E
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase19_cert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }

soviez_p19_cert_env
# Host reboot not required in this focused suite
export SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT=0
export SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION=0
export SOVIEZ_P19_SKIP_COLIMA_REBOOT=1

SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p19-cert-e2e.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

PG_NAME="soviez-p19-cert-pg-$$"
cleanup() {
  # Exact cleanup of disposable containers owned by this run
  if [[ -f "$SOVIEZ_ROOT/pg.name" ]]; then
    docker rm -f "$(cat "$SOVIEZ_ROOT/pg.name")" >/dev/null 2>&1 || true
  fi
  if [[ -d "$SOVIEZ_ROOT/migration/staging" ]]; then
    find "$SOVIEZ_ROOT/migration/staging" -name 'docker.erp' -o -name 'docker.pg' -o -name 'docker.network' 2>/dev/null | while read -r f; do
      id="$(cat "$f" 2>/dev/null || true)"
      [[ -n "$id" ]] || continue
      case "$f" in
        *docker.network) docker network rm "$id" >/dev/null 2>&1 || true ;;
        *) docker rm -f "$id" >/dev/null 2>&1 || true ;;
      esac
    done
  fi
}
trap cleanup EXIT

soviez_p19_start_pg "$PG_NAME" >/dev/null
echo "$PG_NAME" > "$SOVIEZ_ROOT/pg.name"
# Ensure dump/restore CIDs survive (start_pg exports; re-assert for safety)
export SOVIEZ_MIG_PG_DUMP_CID="$PG_NAME"
export SOVIEZ_MIG_PG_RESTORE_CID="$PG_NAME"
export SOVIEZ_MIG_PG_PASSWORD=odoo
export SOVIEZ_MIG_PG_USER=odoo
export SOVIEZ_MIG_SOURCE_DB_NAME=soviez_src

# Filestore + Stage fixtures
FS="$SOVIEZ_ROOT/filestore"; mkdir -p "$FS/ab/cd"; echo attachment > "$FS/ab/cd/logo.png"
export SOVIEZ_MIG_FIXTURE_FILESTORE_ROOT="$FS"
STAGE_FS="$SOVIEZ_ROOT/stage_fs/stage-eligible"; mkdir -p "$STAGE_FS"; echo stage-att > "$STAGE_FS/file.bin"
export SOVIEZ_MIG_STAGE_FILESTORE_ROOT="$SOVIEZ_ROOT/stage_fs"
export SOVIEZ_MIG_STAGE_DB_NAME=soviez_stage_eligible
ADDON_DIR="$SOVIEZ_ROOT/addon_pkg/demo_addon"; mkdir -p "$ADDON_DIR"
printf '{\n  "name": "demo_addon"\n}\n' > "$ADDON_DIR/__manifest__.py"
export SOVIEZ_MIG_STAGE_ADDON_DIR="$ADDON_DIR"

# Stage inventory in discovery fixture
export SOVIEZ_MIG_FIXTURE_STAGES_JSON
SOVIEZ_MIG_FIXTURE_STAGES_JSON="$(python3 - <<'PY'
import json
print(json.dumps({"stages":[
  {"stage_id":"stage-eligible","parent_production_id":"prod-p19-cert","status":"active","entitlement":"ok","retention_ends_at":"2099-01-01T00:00:00Z","expired":False,"selectable":True},
  {"stage_id":"stage-expired","parent_production_id":"prod-p19-cert","status":"expired","entitlement":"expired","retention_ends_at":"2020-01-01T00:00:00Z","expired":True,"selectable":False},
]}))
PY
)"

soviez_p19_pair_bootstrap prod-p19-cert lic-p19-cert p19cert.example.test

# Select stages
soviez_migration_stage_select "$PAIR_ID" stage-eligible select >/dev/null
soviez_migration_stage_mark_optional "$PAIR_ID" stage-eligible >/dev/null || true
# expired must be denied when selected
set +e
( soviez_migration_stage_eligibility_check "$PAIR_ID" stage-expired >/dev/null 2>&1 )
elig_rc=$?
set -e
[[ "$elig_rc" -ne 0 ]] || { echo "FAIL: expired stage should be ineligible"; exit 1; }
echo "OK: expired stage denied"

# Cert mode forbids local transfer
set +e
( SOVIEZ_MIG_TRANSFER_LOCAL=1 soviez_migration_channel_init "$PAIR_ID" "op-forbid" "man-forbid" >/tmp/p19-local-forbid.out 2>&1 )
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: local channel must fail in cert"; exit 1; }
echo "OK: local-copy forbidden in certification"

# Pre-freeze write succeeds via guard started by freeze — first run freeze cycle standalone
OP_PROBE="$(soviez_migration_new_id freezeprobe)"
# Start guard without freeze marker first
soviez_migration_freeze_guard_start "$PAIR_ID" "$OP_PROBE" "prod-p19-cert" >/dev/null
PROBE_BEFORE="$(soviez_migration_freeze_write_probe "$OP_PROBE" POST)"
echo "$PROBE_BEFORE" | grep -q '"http_code":200' || { echo "FAIL pre-freeze write: $PROBE_BEFORE"; exit 1; }
echo "OK: pre-freeze write allowed"

# Authoritative transfer start (real mTLS, real dump/restore, real ERP)
OUT="$(soviez_migration_transfer_start "$PAIR_ID" "$ROUTING_ID")"
echo "$OUT" | tee "$SOVIEZ_ROOT/transfer.out"
OP_ID="$(soviez_json_get "$OUT" operation_id)"
STAGING_ID="$(soviez_json_get "$OUT" destination_staging_id)"
CH_MODE="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$OP_ID")")" mode)"
[[ "$CH_MODE" == "mtls" ]] || { echo "FAIL channel mode=$CH_MODE"; exit 1; }
echo "OK: real mTLS channel"

DUMP="$(soviez_migration_transfer_op_dir "$OP_ID")/database/dump.fc"
[[ -f "$DUMP" ]] || { echo "FAIL missing dump"; exit 1; }
head -c 5 "$DUMP" | grep -q PGDMP
RESTORE_MODE="$(soviez_json_get "$(cat "$(soviez_migration_staging_dir "$STAGING_ID")/database/restore.json")" mode)"
[[ "$RESTORE_MODE" == "pg_restore_docker" ]] || { echo "FAIL restore mode=$RESTORE_MODE"; exit 1; }
echo "OK: real pg_dump + pg_restore"

START_MODE="$(soviez_json_get "$(cat "$(soviez_migration_staging_dir "$STAGING_ID")/startup.json")" mode)"
[[ "$START_MODE" == "real_soviez_erp" ]] || { echo "FAIL erp mode=$START_MODE"; exit 1; }
LOGIN_CODE="$(soviez_json_get "$(cat "$(soviez_migration_staging_dir "$STAGING_ID")/startup.json")" login_http_code)"
[[ "$LOGIN_CODE" == "200" ]] || { echo "FAIL login=$LOGIN_CODE"; exit 1; }
echo "OK: real ERP /web/login 200"

# Token / cutover / freeze terminal
ST="$(cat "$(soviez_migration_transfer_op_dir "$OP_ID")/state.json")"
echo "$ST" | grep -q '"migration_token_reserved":false\|"migration_token_reserved": false'
echo "$ST" | grep -q '"migration_token_consumed":false\|"migration_token_consumed": false'
echo "$ST" | grep -q '"destination_production_activated":false\|"destination_production_activated": false'
echo "$ST" | grep -q '"traffic_cutover_started":false\|"traffic_cutover_started": false'
FR="$(cat "$(soviez_migration_freeze_state_path "$OP_ID")")"
echo "$FR" | grep -Eq '"released":true|"released": true'
echo "OK: token/cutover/freeze terminal bounds"

# During-freeze denial proof (dedicated short freeze)
OP_FZ="$(soviez_migration_new_id fzenforce)"
export SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS=30
export SOVIEZ_MIG_FREEZE_WATCHDOG=0
soviez_migration_freeze_start "$PAIR_ID" "$OP_FZ" >/dev/null
PROBE_DURING="$(soviez_migration_freeze_write_probe "$OP_FZ" POST)"
echo "$PROBE_DURING" | grep -q '"http_code":503' || { echo "FAIL during freeze: $PROBE_DURING"; exit 1; }
# GET read-only still ok
PROBE_GET="$(soviez_migration_freeze_write_probe "$OP_FZ" GET)"
echo "$PROBE_GET" | grep -q '"http_code":200' || { echo "FAIL read during freeze: $PROBE_GET"; exit 1; }
soviez_migration_freeze_release "$PAIR_ID" "$OP_FZ" "normal_completion" >/dev/null
# Keep guard for post write
export SOVIEZ_MIG_FREEZE_KEEP_GUARD=1
# restart guard after release stopped it — re-start for post proof
soviez_migration_freeze_guard_start "$PAIR_ID" "$OP_FZ" "prod-p19-cert" >/dev/null
PROBE_AFTER="$(soviez_migration_freeze_write_probe "$OP_FZ" POST)"
echo "$PROBE_AFTER" | grep -q '"http_code":200' || { echo "FAIL post-freeze write: $PROBE_AFTER"; exit 1; }
echo "OK: application write-freeze enforcement"

# Mandatory stage failure
export SOVIEZ_MIG_STAGE_FORCE_FAIL=mandatory
set +e
soviez_migration_stages_transfer "$PAIR_ID" "$OP_ID" "$(soviez_json_get "$OUT" manifest_id 2>/dev/null || echo man)" "$STAGING_ID" >/dev/null
mrc=$?
set -e
[[ "$mrc" -eq 2 ]] || { echo "FAIL mandatory stage rc=$mrc"; exit 1; }
unset SOVIEZ_MIG_STAGE_FORCE_FAIL
export SOVIEZ_MIG_STAGE_FORCE_FAIL=optional
set +e
soviez_migration_stages_transfer "$PAIR_ID" "$OP_ID" man "$STAGING_ID" >/dev/null
orc=$?
set -e
[[ "$orc" -eq 1 ]] || { echo "FAIL optional stage rc=$orc"; exit 1; }
unset SOVIEZ_MIG_STAGE_FORCE_FAIL
echo "OK: mandatory BLOCKED / optional WARNING"

echo "test_phase19_real_mtls_e2e: PASS"
