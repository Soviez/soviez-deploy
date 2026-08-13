#!/usr/bin/env bash
# Gap 2 — Full offline request → package → import → create (no SaaS on target).
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
export SOVIEZ_STAGE_OFFLINE_SKIP_TOOLING_HASH=1
# Simulate air-gapped target: no SaaS endpoints
unset SOVIEZ_SAAS_BASE_URL SOVIEZ_API_BASE_URL || true
export SOVIEZ_STAGE_BLOCK_SAAS=1

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
mkdir -p "$SOVIEZ_ROOT/fixtures/prod-filestore"
printf 'offline-blob\n' > "$SOVIEZ_ROOT/fixtures/prod-filestore/attachment.bin"
export SOVIEZ_STAGE_FIXTURE_FILESTORE="$SOVIEZ_ROOT/fixtures/prod-filestore"

SID=stageoff1
DOMAIN=stageoff1.example.com
OP=op-offline-full-1
REQ_OUT="$SOVIEZ_ROOT/offline-req.json"

echo "==> export offline request"
SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" SOVIEZ_CLI_OFFLINE_OUT="$REQ_OUT" \
  soviez_cmd_stage_offline_request
assert_file_exists "$REQ_OUT"
assert_contains "$(cat "$REQ_OUT")" "soviez.stage-offline-request.v1"
assert_contains "$(cat "$REQ_OUT")" "request_nonce"

# Connected-device package issuance (disposable keys) — not SaaS on target
pkg_dir="$(mktemp -d)"
node "$ROOT/tests/helpers/issue_offline_package.mjs" "$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_1",
  "database_uuid": "db-uuid-prod-1",
  "stage_id": "$SID",
  "stage_domain": "$DOMAIN",
  "operation_id": "$OP",
  "host_pubkey_fingerprint": "fp_host_fixture",
  "release_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "tooling_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
}))
PY
)" "$pkg_dir" >/dev/null
PKG="$pkg_dir/offline-package.json"
assert_file_exists "$PKG"
# Package must not contain private keys
! grep -q "BEGIN PRIVATE KEY" "$PKG"

echo "==> import + create offline (no SaaS)"
SOVIEZ_CLI_OFFLINE_PACKAGE="$PKG" SOVIEZ_CLI_STAGE_ID="$SID" SOVIEZ_CLI_STAGE_DOMAIN="$DOMAIN" \
  SOVIEZ_CLI_OP_ID="$OP" \
  soviez_cmd_stage_offline_import

assert_file_exists "$(soviez_stage_identity_file "$SID")"
assert_file_exists "$(soviez_stage_origin_cert_file "$SID")"
assert_eq "completed" "$(soviez_stage_op_read_state "$OP")"
assert_file_exists "$SOVIEZ_STAGE_LEDGER"

echo "==> replay package must fail (ledger)"
set +e
( SOVIEZ_CLI_OFFLINE_PACKAGE="$PKG" SOVIEZ_CLI_STAGE_ID=stageoff2 SOVIEZ_CLI_STAGE_DOMAIN=stageoff2.example.com \
  SOVIEZ_CLI_OP_ID=op-offline-replay \
  soviez_cmd_stage_offline_import >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "replay must fail"

echo "==> wrong Production fingerprint binding denied"
bad_dir="$(mktemp -d)"
node "$ROOT/tests/helpers/issue_offline_package.mjs" "$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "WRONG_FP",
  "database_uuid": "db-uuid-prod-1",
  "stage_id": "stageoff3",
  "stage_domain": "stageoff3.example.com",
  "operation_id": "op-offline-badfp",
  "host_pubkey_fingerprint": "fp_host_fixture",
  "release_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "tooling_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
}))
PY
)" "$bad_dir" >/dev/null
set +e
( SOVIEZ_CLI_OFFLINE_PACKAGE="$bad_dir/offline-package.json" \
  SOVIEZ_CLI_STAGE_ID=stageoff3 SOVIEZ_CLI_STAGE_DOMAIN=stageoff3.example.com \
  SOVIEZ_CLI_OP_ID=op-offline-badfp \
  soviez_cmd_stage_offline_import >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "wrong fingerprint must fail"

echo "==> expired package denied"
exp_dir="$(mktemp -d)"
node "$ROOT/tests/helpers/issue_offline_package.mjs" "$(python3 - <<PY
import json, time
print(json.dumps({
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_1",
  "database_uuid": "db-uuid-prod-1",
  "stage_id": "stageoff4",
  "stage_domain": "stageoff4.example.com",
  "operation_id": "op-offline-exp",
  "host_pubkey_fingerprint": "fp_host_fixture",
  "release_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "tooling_digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "start_before_epoch": int(time.time()) - 10,
  "exp": int(time.time()) - 10,
}))
PY
)" "$exp_dir" >/dev/null
set +e
( SOVIEZ_CLI_OFFLINE_PACKAGE="$exp_dir/offline-package.json" \
  SOVIEZ_CLI_STAGE_ID=stageoff4 SOVIEZ_CLI_STAGE_DOMAIN=stageoff4.example.com \
  SOVIEZ_CLI_OP_ID=op-offline-exp \
  soviez_cmd_stage_offline_import >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "expired package must fail"

echo "OFFLINE_FULL_E2E: PASS"
