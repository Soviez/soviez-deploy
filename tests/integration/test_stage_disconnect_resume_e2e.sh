#!/usr/bin/env bash
# Gap 3a — Actually exercised disconnect/resume via durable worker + pause hooks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=1
export SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE=1
export SOVIEZ_STAGE_DNS_OK=1
export SOVIEZ_STAGE_ADMISSION_FORCE=1
export SOVIEZ_HOST_PUBKEY_FINGERPRINT=fp_host_fixture
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_STAGE_INSTALLER_PATH="$ROOT/dist/soviez.sh"
export SOVIEZ_STAGE_PAUSE_MAX_SEC=90

if [[ ! -f "$ROOT/services/stage-operation-helper/dist/src/cli.js" ]]; then
  (cd "$ROOT/services/stage-operation-helper" && npm run build >/dev/null)
fi
wrap="$(mktemp)"
cat > "$wrap" <<EOF
#!/usr/bin/env bash
exec node "$ROOT/services/stage-operation-helper/dist/src/cli.js" "\$@"
EOF
chmod +x "$wrap"
export SOVIEZ_STAGE_HELPER_BIN="$wrap"

soviez_paths_init
soviez_stage_paths_init

PROD_JSON='{"tenant_id":"tenant-prod-1","domain":"prod.example.com","license_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","release_version":"1.0.0","database_name":"production","database_uuid":"db-uuid-prod-1","production_fingerprint":"prod_fp_1","container":"soviez-web-1","container_status":"running","filestore_path":""}'
export SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON="$PROD_JSON"
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true}'
mkdir -p "$SOVIEZ_ROOT/fixtures/prod-filestore"
printf 'resume-blob\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$SOVIEZ_ROOT/fixtures/prod-filestore"

prepare_ticket() {
  local sid="$1" domain="$2" op="$3"
  local work
  work="$(mktemp -d)"
  node "$ROOT/tests/helpers/issue_stage_ticket.mjs" "$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_1",
  "database_uuid": "db-uuid-prod-1",
  "stage_id": "$sid",
  "stage_domain": "$domain",
  "release_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "tooling_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "operation_id": "$op",
  "host_pubkey_fingerprint": "fp_host_fixture",
}))
PY
)" "$work" >/dev/null
  export SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN
  SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN="$(cat "$work/ticket.token")"
  export SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON
  SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON="$(cat "$work/keys.json")"
  export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON
  SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "ok": True,
  "authorization_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "ticket": {"token": open("$work/ticket.token").read().strip()},
  "ticket_token": open("$work/ticket.token").read().strip(),
  "existing_stages_unaffected": True,
}))
PY
)"
  soviez_stage_op_create "$op" >/dev/null
  mkdir -p "$(soviez_stage_op_dir "$op")/auth"
  cp "$work/keys.json" "$(soviez_stage_op_dir "$op")/auth/keys.json"
}

wait_paused() {
  local op="$1" state="$2" i=0
  while [[ ! -f "$(soviez_stage_op_dir "$op")/paused" ]]; do
    i=$((i + 1))
    [[ $i -lt 300 ]] || { echo "timeout waiting pause at $state"; cat "$(soviez_stage_op_dir "$op")/worker.log" 2>/dev/null || true; return 1; }
    sleep 0.2
  done
  assert_eq "$state" "$(cat "$(soviez_stage_op_dir "$op")/paused")"
}

resume_op() {
  local op="$1"
  touch "$(soviez_stage_op_dir "$op")/resume"
}

wait_state() {
  local op="$1" want="$2" i=0
  while [[ "$(soviez_stage_op_read_state "$op")" != "$want" ]]; do
    i=$((i + 1))
    [[ $i -lt 400 ]] || { echo "timeout waiting state=$want have=$(soviez_stage_op_read_state "$op")"; cat "$(soviez_stage_op_dir "$op")/worker.log" 2>/dev/null || true; return 1; }
    sleep 0.25
  done
}

run_checkpoint() {
  local pause_at="$1" sid="$2" domain="$3" op="$4"
  echo "==> disconnect/resume at $pause_at"
  prepare_ticket "$sid" "$domain" "$op"
  export SOVIEZ_STAGE_PAUSE_AT="$pause_at"
  export SOVIEZ_STAGE_DURABLE_WORKER=1
  # Controller starts worker and returns immediately
  SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="$op" \
    SOVIEZ_CLI_STAGE_ID="$sid" SOVIEZ_CLI_STAGE_DOMAIN="$domain" \
    soviez_cmd_stage_create_run
  # Simulate SSH disconnect: controller gone; worker continues until pause
  wait_paused "$op" "$pause_at"
  assert_eq 1 "$(soviez_stage_worker_alive "$op" && echo 1 || echo 0)" "worker must be alive while paused"
  # Reattach via CLI path (view state)
  local st
  st="$(soviez_stage_op_read_state "$op")"
  assert_eq "$pause_at" "$st"
  # Resume worker
  resume_op "$op"
  wait_state "$op" completed
  assert_file_exists "$(soviez_stage_origin_cert_file "$sid")"
  # No secrets in worker unit / state
  ! grep -Eiq 'BEGIN PRIVATE KEY|password=|activation_key' "$(soviez_systemd_unit_path "$op")" || false
  ! grep -Eiq 'BEGIN PRIVATE KEY' "$(soviez_stage_op_state_file "$op")" || false
  unset SOVIEZ_STAGE_PAUSE_AT SOVIEZ_STAGE_DURABLE_WORKER
}

# Required interruption points
run_checkpoint operation_authorized stage-dr-auth stage-dr-auth.example.com op-dr-auth
run_checkpoint database_snapshot_created stage-dr-dump stage-dr-dump.example.com op-dr-dump
run_checkpoint filestore_snapshot_created stage-dr-fs stage-dr-fs.example.com op-dr-fs
run_checkpoint database_restoring stage-dr-restore stage-dr-restore.example.com op-dr-restore
run_checkpoint neutralization_running stage-dr-neut stage-dr-neut.example.com op-dr-neut
run_checkpoint ssl_pending stage-dr-ssl stage-dr-ssl.example.com op-dr-ssl
run_checkpoint origin_certificate_issued stage-dr-cert stage-dr-cert.example.com op-dr-cert

# Kill controller mid-flight: durable worker still completes after process restart
echo "==> worker restart after kill"
OP=op-dr-restart
SID=stage-dr-restart
DOMAIN=stage-dr-restart.example.com
prepare_ticket "$SID" "$DOMAIN" "$OP"
export SOVIEZ_STAGE_PAUSE_AT=ticket_verified
export SOVIEZ_STAGE_DURABLE_WORKER=1
SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="$OP" SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  soviez_cmd_stage_create_run
wait_paused "$OP" ticket_verified
# Kill worker (simulate crash), then restart via reattach create_run without reminting auth
kill "$(cat "$(soviez_stage_worker_pid_file "$OP")")" 2>/dev/null || true
sleep 0.5
# Clear pause for restart
rm -f "$(soviez_stage_op_dir "$OP")/paused"
unset SOVIEZ_STAGE_PAUSE_AT
export SOVIEZ_STAGE_DURABLE_WORKER=0
export SOVIEZ_STAGE_WORKER_INNER=1
# Reload fixtures from files written by durable launcher
export SOVIEZ_STAGE_FIXTURE_TICKET_FROM_FILE=1
export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_FROM_FILE=1
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_FROM_FILE=1
SOVIEZ_CLI_OP_ID="$OP" SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  soviez_cmd_stage_create_run
assert_eq "completed" "$(soviez_stage_op_read_state "$OP")"
# Authorization not reminted — same authorization_id
auth_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$OP")")" authorization_id)"
assert_eq "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee" "$auth_id"

echo "DISCONNECT_RESUME_E2E: PASS"
