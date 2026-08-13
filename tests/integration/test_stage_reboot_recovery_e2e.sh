#!/usr/bin/env bash
# Gap 3b — Isolated container reboot recovery for Stage durable worker.
# Uses already-present postgres:16 image as disposable reboot-capable host substitute
# (macOS workstation has no systemctl/systemd-nspawn).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"

bash "$ROOT/build/assemble.sh" >/dev/null

CONTAINER="soviez-stage-reboot-e2e-$$"
# Colima on this host only reliably bind-mounts under $HOME (not /tmp or /Volumes/PortableSSD).
WORKDIR="$(mktemp -d "$HOME/.soviez-stage-reboot-XXXXXX")"
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$WORKDIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$WORKDIR/root" "$WORKDIR/bin"
cp "$ROOT/dist/soviez.sh" "$WORKDIR/bin/soviez.sh"
# Helper + ticket issuer need node inside container — run orchestration on host with
# state dir bind-mounted, and use docker restart of a long-lived worker sidecar that
# only owns the heartbeat/supervisor loop + state volume. Strongest available without
# pulling a systemd image: disposable container restart with persisted SOVIEZ_ROOT.

# Host-side stage create with pause, then restart a companion container that holds
# the "host identity" marker and proves reconciliation after container reboot.

# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="$WORKDIR/root"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=1
export SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE=1
export SOVIEZ_STAGE_DNS_OK=1
export SOVIEZ_STAGE_ADMISSION_FORCE=1
export SOVIEZ_HOST_PUBKEY_FINGERPRINT=fp_host_fixture
export SOVIEZ_STAGE_INSTALLER_PATH="$ROOT/dist/soviez.sh"
export SOVIEZ_STAGE_PAUSE_MAX_SEC=120

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
printf 'reboot-blob\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$SOVIEZ_ROOT/fixtures/prod-filestore"

OP=op-reboot-1
SID=stage-reboot-1
DOMAIN=stage-reboot-1.example.com
work="$(mktemp -d)"
node "$ROOT/tests/helpers/issue_stage_ticket.mjs" "$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_1",
  "database_uuid": "db-uuid-prod-1",
  "stage_id": "$SID",
  "stage_domain": "$DOMAIN",
  "release_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "tooling_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "operation_id": "$OP",
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
soviez_stage_op_create "$OP" >/dev/null
mkdir -p "$(soviez_stage_op_dir "$OP")/auth"
cp "$work/keys.json" "$(soviez_stage_op_dir "$OP")/auth/keys.json"

# Start disposable host container with bind-mounted state; entrypoint loops heartbeat + resume marker watch.
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" \
  -v "$SOVIEZ_ROOT:/soviez-root" \
  -e SOVIEZ_OP="$OP" \
  --entrypoint bash \
  postgres:16 \
  -lc 'mkdir -p /soviez-root/ops/stage/$SOVIEZ_OP; echo booted-$(date -u +%Y%m%dT%H%M%SZ) >> /soviez-root/ops/stage/$SOVIEZ_OP/host_boot.log; while true; do date -u +%Y-%m-%dT%H:%M:%SZ > /soviez-root/ops/stage/$SOVIEZ_OP/host_heartbeat; sleep 1; done' \
  >/dev/null

# Wait for first boot marker
i=0
while [[ ! -f "$(soviez_stage_op_dir "$OP")/host_boot.log" ]]; do
  i=$((i + 1)); [[ $i -lt 50 ]] || { echo "container boot failed"; docker logs "$CONTAINER"; exit 1; }
  sleep 0.2
done
BOOTS_BEFORE="$(wc -l < "$(soviez_stage_op_dir "$OP")/host_boot.log" | tr -d ' ')"

export SOVIEZ_STAGE_PAUSE_AT=filestore_snapshot_created
export SOVIEZ_STAGE_DURABLE_WORKER=1
SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="$OP" SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  soviez_cmd_stage_create_run

# Wait until paused
i=0
while [[ ! -f "$(soviez_stage_op_dir "$OP")/paused" ]]; do
  i=$((i + 1)); [[ $i -lt 300 ]] || { echo "pause timeout"; cat "$(soviez_stage_op_dir "$OP")/worker.log" || true; exit 1; }
  sleep 0.2
done
assert_eq "filestore_snapshot_created" "$(cat "$(soviez_stage_op_dir "$OP")/paused")"

# Kill host-side worker (simulate host process death during reboot window)
if [[ -f "$(soviez_stage_worker_pid_file "$OP")" ]]; then
  kill "$(cat "$(soviez_stage_worker_pid_file "$OP")")" 2>/dev/null || true
fi

# Actual disposable container reboot
docker restart "$CONTAINER" >/dev/null
i=0
while true; do
  BOOTS_AFTER="$(wc -l < "$(soviez_stage_op_dir "$OP")/host_boot.log" | tr -d ' ')"
  [[ "$BOOTS_AFTER" -gt "$BOOTS_BEFORE" ]] && break
  i=$((i + 1)); [[ $i -lt 50 ]] || { echo "reboot marker missing"; docker logs "$CONTAINER"; exit 1; }
  sleep 0.2
done
assert_ne "$BOOTS_BEFORE" "$BOOTS_AFTER" "container reboot must append boot log"
[[ "$BOOTS_AFTER" -gt "$BOOTS_BEFORE" ]] || { echo "boots did not increase"; exit 1; }

# After reboot: reconcile via CLI reattach (resume create from checkpoint)
rm -f "$(soviez_stage_op_dir "$OP")/paused"
unset SOVIEZ_STAGE_PAUSE_AT
export SOVIEZ_STAGE_DURABLE_WORKER=0
export SOVIEZ_STAGE_WORKER_INNER=1
export SOVIEZ_STAGE_FIXTURE_TICKET_FROM_FILE=1
export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_FROM_FILE=1
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_FROM_FILE=1

# Prove dump already complete is not blindly redone as empty — snapshot file must remain
assert_file_exists "$(soviez_stage_snapshot_dir "$OP")/db.dump"
DUMP_SUM_BEFORE="$(shasum -a 256 "$(soviez_stage_snapshot_dir "$OP")/db.dump" | awk '{print $1}')"

SOVIEZ_CLI_OP_ID="$OP" SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  soviez_cmd_stage_create_run

assert_eq "completed" "$(soviez_stage_op_read_state "$OP")"
DUMP_SUM_AFTER="$(shasum -a 256 "$(soviez_stage_snapshot_dir "$OP")/db.dump" | awk '{print $1}')"
assert_eq "$DUMP_SUM_BEFORE" "$DUMP_SUM_AFTER" "completed dump must not be rewritten on resume"
assert_file_exists "$(soviez_stage_origin_cert_file "$SID")"

# Host heartbeat still advancing post-reboot
HB1="$(cat "$(soviez_stage_op_dir "$OP")/host_heartbeat")"
sleep 2
HB2="$(cat "$(soviez_stage_op_dir "$OP")/host_heartbeat")"
assert_ne "$HB1" "$HB2" "post-reboot host heartbeat must advance"

echo "REBOOT_RECOVERY_E2E: PASS container=$CONTAINER boots=$BOOTS_AFTER"
