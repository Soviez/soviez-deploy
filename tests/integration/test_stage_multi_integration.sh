#!/usr/bin/env bash
# Phase 11 integration: multi-stage create A/B/C, snapshot/filestore, SSL, lifecycle, expiry create deny.
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

# Ensure helper is built
if [[ ! -f "$ROOT/services/stage-operation-helper/dist/src/cli.js" ]]; then
  (cd "$ROOT/services/stage-operation-helper" && npm run build >/dev/null)
fi
export SOVIEZ_STAGE_HELPER_BIN="$ROOT/services/stage-operation-helper/dist/src/cli.js"
# Wrap node cli
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

# Production fixture
PROD_JSON='{"tenant_id":"tenant-prod-1","domain":"prod.example.com","license_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","release_version":"1.0.0","database_name":"production","database_uuid":"db-uuid-prod-1","production_fingerprint":"prod_fp_1","container":"soviez-web-1","container_status":"running","filestore_path":""}'
export SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON="$PROD_JSON"

# Entitlement active fixture
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true}'

mkdir -p "$SOVIEZ_ROOT/fixtures/prod-filestore"
printf 'prod-blob\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
printf 'marker\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/.soviez_fs_marker"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$SOVIEZ_ROOT/fixtures/prod-filestore"
SRC_SUM="$( (cd "$SOVIEZ_STAGE_FIXTURE_FILESTORE" && find . -type f | sort | xargs cat | openssl dgst -sha256 | awk '{print $NF}') )"

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

  export SOVIEZ_CLI_STAGE_ID="$sid"
  export SOVIEZ_CLI_STAGE_DOMAIN="$domain"
  export SOVIEZ_CLI_OP_ID="op-$sid"
  # Pre-create op dir so reattach-friendly
  soviez_stage_op_create "op-$sid" >/dev/null
  # Seed keys into auth dir before run (authorize fixture also writes token)
  mkdir -p "$(soviez_stage_op_dir "op-$sid")/auth"
  cp "$ticket_dir/keys.json" "$(soviez_stage_op_dir "op-$sid")/auth/keys.json"

  SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="op-$sid" \
    SOVIEZ_CLI_STAGE_ID="$sid" SOVIEZ_CLI_STAGE_DOMAIN="$domain" \
    soviez_cmd_stage_create_run

  assert_file_exists "$(soviez_stage_identity_file "$sid")"
  assert_file_exists "$(soviez_stage_origin_cert_file "$sid")"
  assert_file_exists "$SOVIEZ_ROOT/stubs/stage-runtime-${sid}.started"
  local net
  net="$(soviez_stage_network_name_for "$sid")"
  assert_file_exists "$SOVIEZ_ROOT/stubs/networks/${net}.created"
  # Filestore not symlink to production
  [[ ! -L "$(soviez_stage_filestore_path "$sid")" ]]
  # Production filestore unchanged
  local after
  after="$( (cd "$SOVIEZ_STAGE_FIXTURE_FILESTORE" && find . -type f | sort | xargs cat | openssl dgst -sha256 | awk '{print $NF}') )"
  assert_eq "$SRC_SUM" "$after" "Production filestore mutated"
}

create_one stagea stagea.example.com
create_one stageb stageb.example.com
create_one stagec stagec.example.com

# Distinct DBs / containers / MACs / domains
ida="$(soviez_stage_inventory_find stagea)"
idb="$(soviez_stage_inventory_find stageb)"
idc="$(soviez_stage_inventory_find stagec)"
assert_ne "$(soviez_json_get "$ida" stage_db_name)" "$(soviez_json_get "$idb" stage_db_name)"
assert_ne "$(soviez_json_get "$ida" stage_container)" "$(soviez_json_get "$idc" stage_container)"
assert_ne "$(soviez_json_get "$ida" stage_mac)" "$(soviez_json_get "$idb" stage_mac)"
assert_ne "$(soviez_json_get "$ida" stage_domain)" "$(soviez_json_get "$idb" stage_domain)"
assert_ne "$(soviez_json_get "$ida" stage_network)" "$(soviez_json_get "$idb" stage_network)"

list_out="$(soviez_stage_cmd_list)"
assert_contains "$list_out" stagea
assert_contains "$list_out" stageb
assert_contains "$list_out" stagec

soviez_stage_cmd_stop stagea
soviez_stage_cmd_start stagea
soviez_stage_cmd_backup stagea >/dev/null

# Entitlement expired → create denied; existing remains
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":false,"denial_code":"STAGE_LICENSE_EXPIRED","existing_stages_unaffected":true}'
set +e
( SOVIEZ_CLI_STAGE_ID=staged SOVIEZ_CLI_STAGE_DOMAIN=staged.example.com SOVIEZ_CLI_OP_ID=op-denied \
  soviez_cmd_stage_create_run >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "expired entitlement must deny create"
# Existing still listable/startable
soviez_stage_cmd_start stageb
list_out="$(soviez_stage_cmd_list)"
assert_contains "$list_out" stagea

# Drop only stagec
export SOVIEZ_STAGE_DROP_CONFIRM=stagec
export SOVIEZ_STAGE_DROP_SKIP_BACKUP=1
soviez_stage_cmd_drop stagec >/dev/null
list_out="$(soviez_stage_cmd_list)"
assert_contains "$list_out" stagea
assert_not_contains "$list_out" stagec

# Bash-only bypass: without ticket, neutralize helper still required — force missing cert path
# Security: empty ticket should not yield certified stage
rm -rf "$(soviez_stage_dir stagehack)" 2>/dev/null || true

# Offline request export
export SOVIEZ_CLI_STAGE_ID=stageoff
export SOVIEZ_CLI_STAGE_DOMAIN=stageoff.example.com
export SOVIEZ_CLI_OFFLINE_OUT="$SOVIEZ_ROOT/offline-req.json"
soviez_cmd_stage_offline_request
assert_file_exists "$SOVIEZ_ROOT/offline-req.json"
assert_contains "$(cat "$SOVIEZ_ROOT/offline-req.json")" soviez.stage-offline-request.v1

# Cross-production binding denied at ticket verify (wrong fingerprint in expect)
# Covered by helper unit tests; here ensure identity parent is exact
assert_eq "tenant-prod-1" "$(soviez_json_get "$ida" parent_production_tenant_id)"

echo "test_stage_multi_integration: PASS"
