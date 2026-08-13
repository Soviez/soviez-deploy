#!/usr/bin/env bash
# Gap 1 — Real disposable PostgreSQL pg_dump -Fc / pg_restore E2E via Stage installer path.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/stage_live_pg.sh
source "$ROOT/tests/helpers/stage_live_pg.sh"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

cleanup() {
  soviez_test_pg_stop "${SOVIEZ_TEST_PG_CONTAINER:-}" || true
}
trap cleanup EXIT

export SOVIEZ_TEST_MODE=1
export SOVIEZ_STAGE_USE_LIVE_PG=1
export SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=1
export SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE=1
export SOVIEZ_STAGE_DNS_OK=1
export SOVIEZ_STAGE_ADMISSION_FORCE=1
export SOVIEZ_HOST_PUBKEY_FINGERPRINT=fp_host_fixture
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_STAGE_OFFLINE_SKIP_TOOLING_HASH=1

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

echo "==> starting disposable postgres:16"
soviez_test_pg_start livee2e
export SOVIEZ_PG_CONTAINER="$SOVIEZ_TEST_PG_CONTAINER"
export SOVIEZ_PG_HOST="$SOVIEZ_TEST_PG_HOST"
export SOVIEZ_PG_PORT="$SOVIEZ_TEST_PG_PORT"
export SOVIEZ_PG_USER="$SOVIEZ_TEST_PG_USER"
export SOVIEZ_PG_PASSWORD="$SOVIEZ_TEST_PG_PASSWORD"
# Use docker exec pg_dump/pg_restore from postgres:16 image (matches server major).
# Host Homebrew client may be PG15 and would mismatch.

FS="$SOVIEZ_ROOT/fixtures/prod-filestore-live"
rm -rf "$FS"
mkdir -p "$FS"
soviez_test_pg_seed_source soviez_prod_source "$FS"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$FS"

SRC_BEFORE="$(soviez_test_pg_invariant soviez_prod_source)"
FS_BEFORE="$( (cd "$FS" && find . -type f | sort | xargs cat | openssl dgst -sha256 | awk '{print $NF}') )"

PROD_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id": "tenant-prod-live",
  "domain": "prod-live.example.com",
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "release_version": "1.0.0",
  "database_name": "soviez_prod_source",
  "database_uuid": "db-uuid-prod-live-1",
  "production_fingerprint": "prod_fp_live_1",
  "container": "soviez-web-live",
  "container_status": "running",
  "filestore_path": "$FS",
}))
PY
)"
export SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON="$PROD_JSON"
export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true}'

SID=stagelive1
DOMAIN=stagelive1.example.com
OP=op-live-pg-1
work="$(mktemp -d)"
node "$ROOT/tests/helpers/issue_stage_ticket.mjs" "$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_live_1",
  "database_uuid": "db-uuid-prod-live-1",
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

echo "==> running Stage create (live pg_dump/pg_restore)"
T0="$(date +%s)"
SOVIEZ_CLI_COMMAND=stage SOVIEZ_CLI_OP_ID="$OP" \
  SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  soviez_cmd_stage_create_run
T1="$(date +%s)"
echo "create_duration_sec=$((T1 - T0))"

DUMP="$(soviez_stage_snapshot_dir "$OP")/db.dump"
assert_file_exists "$DUMP"
magic="$(dd if="$DUMP" bs=5 count=1 2>/dev/null | tr -d '\0')"
assert_eq "PGDMP" "$magic" "dump must be PostgreSQL custom format"

# Source unchanged
SRC_AFTER="$(soviez_test_pg_invariant soviez_prod_source)"
assert_eq "$SRC_BEFORE" "$SRC_AFTER" "source DB mutated"
FS_AFTER="$( (cd "$FS" && find . -type f | sort | xargs cat | openssl dgst -sha256 | awk '{print $NF}') )"
assert_eq "$FS_BEFORE" "$FS_AFTER" "source filestore mutated"

# Stage DB restored and identity rotated
identity="$(soviez_stage_inventory_find "$SID")"
stage_db="$(soviez_json_get "$identity" stage_db_name)"
stage_uuid="$(soviez_json_get "$identity" stage_database_uuid)"
[[ -n "$stage_db" ]]
partners="$(soviez_test_pg_q "$stage_db" 'SELECT count(*) FROM res_partner')"
moves="$(soviez_test_pg_q "$stage_db" 'SELECT count(*) FROM account_move')"
atts="$(soviez_test_pg_q "$stage_db" 'SELECT count(*) FROM ir_attachment')"
assert_eq "2" "$partners"
assert_eq "3" "$moves"
assert_eq "1" "$atts"

# Relational integrity
orphans="$(soviez_test_pg_q "$stage_db" 'SELECT count(*) FROM account_move m LEFT JOIN res_partner p ON p.id=m.partner_id WHERE p.id IS NULL')"
assert_eq "0" "$orphans"

# Stage UUID distinct from Production
prod_uuid="$(soviez_test_pg_q soviez_prod_source "SELECT value FROM ir_config_parameter WHERE key='database.uuid'")"
stage_param="$(soviez_test_pg_q "$stage_db" "SELECT value FROM ir_config_parameter WHERE key='database.uuid'")"
assert_eq "db-uuid-prod-live-1" "$prod_uuid"
assert_ne "$prod_uuid" "$stage_param" "Stage UUID must differ from Production"
assert_eq "$stage_uuid" "$stage_param"

# Attachment resolves from cloned filestore
store_fname="$(soviez_test_pg_q "$stage_db" 'SELECT store_fname FROM ir_attachment LIMIT 1')"
assert_file_exists "$(soviez_stage_filestore_path "$SID")/$store_fname"
[[ ! -L "$(soviez_stage_filestore_path "$SID")" ]]
assert_file_exists "$(soviez_stage_origin_cert_file "$SID")"

# Retry does not overwrite source; second restore of same stage_db should conflict
set +e
( soviez_stage_restore_database "$OP" "$stage_db" "$DUMP" >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "duplicate Stage DB must fail closed"

echo "LIVE_POSTGRES_E2E: PASS port=$SOVIEZ_TEST_PG_PORT container=$SOVIEZ_TEST_PG_CONTAINER"
