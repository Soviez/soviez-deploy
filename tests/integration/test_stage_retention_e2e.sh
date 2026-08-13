#!/usr/bin/env bash
# Phase 13 integration: retention lifecycle with time fixtures + multi-stage isolation.
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
export SOVIEZ_RETENTION_HOST_TZ=UTC

if [[ ! -f "$ROOT/services/stage-operation-helper/dist/src/cli.js" ]]; then
  (cd "$ROOT/services/stage-operation-helper" && npm run build >/dev/null)
fi
export SOVIEZ_STAGE_HELPER_BIN="$ROOT/services/stage-operation-helper/dist/src/cli.js"
if [[ -f "$SOVIEZ_STAGE_HELPER_BIN" ]]; then
  wrap="$(mktemp)"
  cat > "$wrap" <<EOF
#!/usr/bin/env bash
exec node "$ROOT/services/stage-operation-helper/dist/src/cli.js" "\$@"
EOF
  chmod +x "$wrap"
  export SOVIEZ_STAGE_HELPER_BIN="$wrap"
fi

soviez_paths_init
soviez_stage_paths_init
printf 'ok\n' > "$SOVIEZ_ROOT/production.ok"

PROD_JSON='{"tenant_id":"tenant-prod-1","domain":"prod.example.com","license_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","release_version":"1.0.0","database_name":"production","database_uuid":"db-uuid-prod-1","production_fingerprint":"prod_fp_1","container":"soviez-web-1","container_status":"running","filestore_path":""}'
export SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON="$PROD_JSON"
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true}'

mkdir -p "$SOVIEZ_ROOT/fixtures/prod-filestore"
printf 'prod-blob\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$SOVIEZ_ROOT/fixtures/prod-filestore"

create_one() {
  local sid="$1" domain="$2"
  local work ticket_dir
  work="$(mktemp -d)"
  ticket_dir="$work"
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
  "operation_id": "op-$sid",
  "host_pubkey_fingerprint": "fp_host_fixture",
}))
PY
)" "$ticket_dir" >/dev/null

  export SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN
  SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN="$(cat "$ticket_dir/ticket.token")"
  export SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON
  SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON="$(cat "$ticket_dir/keys.json")"
  export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON
  SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "ok": True,
  "authorization_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "ticket": {"token": open("$ticket_dir/ticket.token").read().strip()},
  "ticket_token": open("$ticket_dir/ticket.token").read().strip(),
  "existing_stages_unaffected": True,
}))
PY
)"
  soviez_stage_op_create "op-$sid" >/dev/null
  mkdir -p "$(soviez_stage_op_dir "op-$sid")/auth"
  cp "$ticket_dir/keys.json" "$(soviez_stage_op_dir "op-$sid")/auth/keys.json"

  SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="op-$sid" \
    SOVIEZ_CLI_STAGE_ID="$sid" SOVIEZ_CLI_STAGE_DOMAIN="$domain" \
    soviez_cmd_stage_create_run

  assert_file_exists "$(soviez_retention_file "$sid")"
  assert_file_exists "$(soviez_retention_banner_file "$sid")"
}

create_one reta ret-a.example.com
create_one retb ret-b.example.com
create_one retc ret-c.example.com

# Default 14-day deadline from immutable created_at
created="$(soviez_json_get "$(soviez_retention_read reta)" created_at)"
expect14="$(soviez_retention_add_calendar_days_utc "$created" 14)"
expect60="$(soviez_retention_add_calendar_days_utc "$created" 60)"
assert_eq "$expect14" "$(soviez_json_get "$(soviez_retention_read reta)" current_retention_deadline)"
assert_eq "$expect60" "$(soviez_json_get "$(soviez_retention_read reta)" maximum_retention_deadline)"

banner="$(cat "$(soviez_retention_banner_file reta)")"
assert_contains "$banner" "Stage environment · Neutralized"
assert_contains "$banner" "remaining"

# Extend B to 30 then 60; C to 60; A stays 14
export SOVIEZ_RETENTION_EXTEND_CONFIRM=retb
soviez_retention_extend retb 30 --yes >/dev/null
soviez_retention_extend retb 60 --yes >/dev/null
export SOVIEZ_RETENTION_EXTEND_CONFIRM=retc
soviez_retention_extend retc 60 --yes >/dev/null
if ( soviez_retention_extend retc 61 --yes ) 2>/dev/null; then
  echo "61 denied" >&2; exit 1
fi
# A unchanged
assert_eq "$expect14" "$(soviez_json_get "$(soviez_retention_read reta)" current_retention_deadline)"

# Entitlement expired — extension still works for existing Stage
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":false,"denial_code":"STAGE_LICENSE_EXPIRED","existing_stages_unaffected":true}'
export SOVIEZ_RETENTION_EXTEND_CONFIRM=reta
# reta still at 14; extend to 30 without entitlement
soviez_retention_extend reta 30 --yes >/dev/null
assert_eq "30" "$(soviez_json_get "$(soviez_retention_read reta)" requested_extension_days)"
soviez_stage_cmd_backup reta >/dev/null
soviez_stage_cmd_status reta >/dev/null

# Safe Shield failure preserves Stage
export SOVIEZ_RETENTION_NOW_UTC
# Force due by clock jump past deadline
deadline="$(soviez_json_get "$(soviez_retention_read reta)" current_retention_deadline)"
export SOVIEZ_RETENTION_NOW_UTC="$(python3 - <<PY
from datetime import datetime, timedelta, timezone
d=datetime.fromisoformat("$deadline".replace("Z","+00:00"))
print((d+timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
soviez_stage_inventory_update_field reta '{"stage_container":"odoo"}'
if ( soviez_retention_run_deletion reta 0 ) 2>/dev/null; then
  echo "shield fail must preserve" >&2; exit 1
fi
assert_file_exists "$(soviez_stage_identity_file reta)"
assert_file_exists "$(soviez_stage_identity_file retb)"
soviez_stage_inventory_update_field reta "{\"stage_container\":\"$(soviez_stage_container_name_for reta)\"}"

# Partial deletion recovery — fail at DB then retry
export SOVIEZ_RETENTION_INJECT_DB_FAIL=1
# Clear prior failure state from shield
soviez_retention_patch reta '{"last_failure_code":null,"retention_status":"deletion_due","deletion_started_at":null,"completed_deletion_steps":[],"final_backup_status":null}'
# Ensure nginx ownership marker for Stage-created nginx stubs
printf '%s\n' reta > "$(soviez_stage_config_path reta)/nginx.owned"
if ( soviez_retention_run_deletion reta 1 ) 2>/tmp/reta-partial.err; then
  echo "partial must fail" >&2; exit 1
fi
st="$(soviez_json_get "$(soviez_retention_read reta)" retention_status)"
fc="$(soviez_json_get "$(soviez_retention_read reta)" last_failure_code)"
steps="$(soviez_json_get "$(soviez_retention_read reta)" completed_deletion_steps)"
assert_eq "recovery_required" "$st"
assert_eq "RETENTION_PARTIAL_DELETION" "$fc"
assert_contains "$steps" "stop_container"
unset SOVIEZ_RETENTION_INJECT_DB_FAIL
soviez_retention_retry reta >/dev/null
assert_file_exists "$(soviez_retention_tombstone_file reta)"
[[ ! -d "$(soviez_stage_dir reta)" ]]
assert_file_exists "$(soviez_stage_identity_file retb)"
assert_file_exists "$(soviez_stage_identity_file retc)"

# Delete B at due (already at max 60) via clock
deadline_b="$(soviez_json_get "$(soviez_retention_read retb)" current_retention_deadline)"
export SOVIEZ_RETENTION_NOW_UTC="$(python3 - <<PY
from datetime import datetime, timedelta
d=datetime.fromisoformat("$deadline_b".replace("Z","+00:00"))
print((d+timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
soviez_retention_run_deletion retb 0 >/dev/null
assert_file_exists "$(soviez_retention_tombstone_file retb)"
assert_file_exists "$(soviez_stage_identity_file retc)"

# Disconnect/resume simulation: inject fail mid-run on retc, reattach by op id
deadline_c="$(soviez_json_get "$(soviez_retention_read retc)" current_retention_deadline)"
export SOVIEZ_RETENTION_NOW_UTC="$(python3 - <<PY
from datetime import datetime, timedelta
d=datetime.fromisoformat("$deadline_c".replace("Z","+00:00"))
print((d+timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
export SOVIEZ_RETENTION_INJECT_FS_FAIL=1
if ( soviez_retention_run_deletion retc 0 ) 2>/dev/null; then
  echo "fs fail expected" >&2; exit 1
fi
op="$(soviez_json_get "$(soviez_retention_read retc)" retention_operation_id)"
unset SOVIEZ_RETENTION_INJECT_FS_FAIL
soviez_cmd_stage_retention_reattach "$op" >/dev/null
assert_file_exists "$(soviez_retention_tombstone_file retc)"

# Reboot recovery: scheduler scan with due stage
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true}'
create_one retd ret-d.example.com
# Simulate reboot: clear locks, jump clock, scan
deadline_d="$(soviez_json_get "$(soviez_retention_read retd)" current_retention_deadline)"
export SOVIEZ_RETENTION_NOW_UTC="$(python3 - <<PY
from datetime import datetime, timedelta
d=datetime.fromisoformat("$deadline_d".replace("Z","+00:00"))
print((d+timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
rmdir "$(soviez_retention_lock_dir retd)" 2>/dev/null || true
soviez_retention_scheduler_scan
assert_file_exists "$(soviez_retention_tombstone_file retd)"

# Production fixture untouched
assert_file_exists "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
assert_eq "ok" "$(cat "$SOVIEZ_ROOT/production.ok")"

echo "test_stage_retention_integration: PASS"
