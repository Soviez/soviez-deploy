#!/usr/bin/env bash
# Phase 20 — unit: token eligibility, commit idempotency, grace, gates, offline
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase20_fixture.sh
source "$ROOT/tests/helpers/phase20_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

pass_count=0
ok() { echo "OK: $1"; pass_count=$((pass_count + 1)); }

die_expect() {
  local label="$1"
  shift
  set +e
  ( set -e; "$@" >/dev/null 2>&1 )
  local rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: $label should fail"; exit 1; }
  ok "$label"
}

# --- token eligibility eligible ---
soviez_phase20_fixture_init "$ROOT"
elig="$(soviez_migration_token_eligibility_p20 "$SOVIEZ_MIG_P20_ACCOUNT_ID" "$SOVIEZ_MIG_P20_LICENSE_ID")"
assert_eq "$(soviez_json_get "$elig" status)" "eligible" "token eligible"
assert_eq "$(soviez_json_get "$elig" available_quantity)" "1" "qty available 1"
ok "token eligibility eligible"

# --- zero quantity denial ---
soviez_phase20_fixture_init "$ROOT"
python3 - <<PY
import sqlite3, os
p = os.environ["SOVIEZ_MIG_P20_LEDGER_PATH"]
conn = sqlite3.connect(p)
conn.execute("UPDATE grants SET quantity_consumed=1, status='exhausted' WHERE grant_id='grant-p20'")
conn.execute("UPDATE wallet SET credits=0 WHERE license_id='lic-p20'")
conn.commit()
PY
elig="$(soviez_migration_token_eligibility_p20 acct-p20 lic-p20)"
assert_eq "$(soviez_json_get "$elig" status)" "unavailable" "zero qty unavailable"
ok "zero quantity denial"

# --- inconsistent ledger denial ---
soviez_phase20_fixture_init "$ROOT"
python3 - <<PY
import sqlite3, os
p = os.environ["SOVIEZ_MIG_P20_LEDGER_PATH"]
conn = sqlite3.connect(p)
conn.execute("UPDATE wallet SET credits=2 WHERE license_id='lic-p20'")
conn.commit()
PY
elig="$(soviez_migration_token_eligibility_p20 acct-p20 lic-p20)"
assert_eq "$(soviez_json_get "$elig" ledger_consistent)" "False" "ledger inconsistent flag"
assert_eq "$(soviez_json_get "$elig" status)" "unavailable" "inconsistent ledger unavailable"
ok "inconsistent ledger denial"

# --- successful commit → qty 0, slot_count 1, auth committed ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
assert_eq "$(soviez_json_get "$receipt" transaction_status)" "committed" "auth committed"
snap="$(soviez_migration_p20_ledger snapshot --license-id lic-p20)"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "grant remaining 0"
assert_eq "$(soviez_json_get "$snap" slot_count)" "1" "slot_count 1"
assert_eq "$(soviez_json_get "$snap" committed_authorizations)" "1" "one committed auth"
[[ -f "$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json" ]]
ok "successful commit qty 0 slot 1"

# --- idempotent retry same key/same payload → same authorization_id (ledger get) ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-retry-same"
r1="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
aid1="$(soviez_json_get "$r1" authorization_id)"
r2="$(soviez_migration_p20_ledger get --account-id acct-p20 --idempotency-key "$SOVIEZ_MIG_P20_IDEMPOTENCY_KEY")"
aid2="$(soviez_json_get "$r2" authorization_id)"
assert_eq "$aid1" "$aid2" "idempotent same auth id"
snap="$(soviez_migration_p20_ledger snapshot --license-id lic-p20)"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "idempotent retry still qty 0"
ok "idempotent retry same key payload"

# --- same key different payload → MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT (ledger) ---
soviez_phase20_fixture_init "$ROOT"
payload_a="$(SOVIEZ_PAIR="$PAIR_ID" SOVIEZ_IDEM="idem-conflict" python3 - <<'PY'
import json, hashlib, os
body={
 "account_id":"acct-p20","license_id":"lic-p20","pair_id":os.environ["SOVIEZ_PAIR"],
 "idempotency_key":os.environ["SOVIEZ_IDEM"],"grant_id":"grant-p20","staging_id":"staging-fixture",
 "source_fp":"fp-source","dest_fp":"fp-dest",
 "source_db_uuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
 "dest_db_uuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
 "source_digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
 "dest_digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
 "operation_id":"op-conflict-a",
}
raw=json.dumps({k:v for k,v in body.items()},separators=(",",":"),sort_keys=True)
body["request_hash"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(body,separators=(",",":")))
PY
)"
soviez_migration_p20_ledger commit --payload-json "$payload_a" >/dev/null
payload_b="$(SOVIEZ_PAIR="$PAIR_ID" SOVIEZ_IDEM="idem-conflict" python3 - <<'PY'
import json, hashlib, os
body={
 "account_id":"acct-p20","license_id":"lic-p20","pair_id":os.environ["SOVIEZ_PAIR"],
 "idempotency_key":os.environ["SOVIEZ_IDEM"],"grant_id":"grant-p20","staging_id":"staging-fixture",
 "source_fp":"fp-source","dest_fp":"fp-dest-other",
 "source_db_uuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
 "dest_db_uuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
 "source_digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
 "dest_digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
 "operation_id":"op-conflict-b",
}
raw=json.dumps({k:v for k,v in body.items()},separators=(",",":"),sort_keys=True)
body["request_hash"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(body,separators=(",",":")))
PY
)"
set +e
soviez_migration_p20_ledger commit --payload-json "$payload_b" >/dev/null 2>/tmp/p20-idem-conflict.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT /tmp/p20-idem-conflict.err
ok "same key different payload conflict"

# --- second commit different key same license → conflict (ledger) ---
soviez_phase20_fixture_init "$ROOT"
soviez_migration_authorization_commit "$PAIR_ID" 1 >/dev/null
payload_other="$(SOVIEZ_PAIR="$PAIR_ID" python3 - <<'PY'
import json, hashlib, os
body={
 "account_id":"acct-p20","license_id":"lic-p20","pair_id":os.environ["SOVIEZ_PAIR"],
 "idempotency_key":"idem-second-commit","grant_id":"grant-p20","staging_id":"staging-fixture",
 "source_fp":"fp-dest",
 "dest_fp":"fp-dest-alt",
 "source_db_uuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
 "dest_db_uuid":"cccccccc-cccc-cccc-cccc-cccccccccccc",
 "source_digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
 "dest_digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
 "operation_id":"op-second",
}
raw=json.dumps({k:v for k,v in body.items()},separators=(",",":"),sort_keys=True)
body["request_hash"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(body,separators=(",",":")))
PY
)"
set +e
soviez_migration_p20_ledger commit --payload-json "$payload_other" >/dev/null 2>/tmp/p20-second-commit.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_ACTIVE_OPERATION_CONFLICT /tmp/p20-second-commit.err
ok "second commit different key conflict"

# --- concurrent: two commits same key → one auth, qty 0 ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-concurrent-$$"
(
  soviez_migration_authorization_commit "$PAIR_ID" 1 >/tmp/p20-conc-a.out 2>/tmp/p20-conc-a.err &
  soviez_migration_authorization_commit "$PAIR_ID" 1 >/tmp/p20-conc-b.out 2>/tmp/p20-conc-b.err &
  wait
) || true
snap="$(soviez_migration_p20_ledger snapshot --license-id lic-p20)"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "concurrent qty 0"
assert_eq "$(soviez_json_get "$snap" committed_authorizations)" "1" "concurrent one auth"
aid_a="$(soviez_json_get "$(cat /tmp/p20-conc-a.out 2>/dev/null || echo '{}')" authorization_id 2>/dev/null || true)"
aid_b="$(soviez_json_get "$(cat /tmp/p20-conc-b.out 2>/dev/null || echo '{}')" authorization_id 2>/dev/null || true)"
[[ -n "$aid_a" || -n "$aid_b" ]]
if [[ -n "$aid_a" && -n "$aid_b" ]]; then
  assert_eq "$aid_a" "$aid_b" "concurrent same auth id"
fi
ok "concurrent same key one auth"

# --- source grace apply + deny update/clone ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
grace="$(soviez_migration_source_grace_apply "$auth_id")"
assert_contains "$grace" "migration_origin_grace" "grace state"
assert_contains "$grace" "denies" "grace denies present"
die_expect "grace denies update" soviez_migration_source_grace_assert_allowed update
die_expect "grace denies clone" soviez_migration_source_grace_assert_allowed clone
ok "source grace apply and deny update/clone"

# --- destination binding production_licensed_pre_cutover, public_route false ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
bind="$(soviez_migration_destination_binding_apply "$auth_id")"
assert_eq "$(soviez_json_get "$bind" status)" "production_licensed_pre_cutover" "dest pre cutover"
assert_eq "$(soviez_json_get "$bind" public_route)" "False" "public_route false"
[[ -f "$SOVIEZ_MIG_ROOT/activation/$auth_id/public_route" ]]
grep -q false "$SOVIEZ_MIG_ROOT/activation/$auth_id/public_route"
ok "destination binding pre_cutover public_route false"

# --- split-brain inject blocks ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
soviez_migration_destination_binding_apply "$auth_id" >/dev/null
soviez_migration_source_grace_apply "$auth_id" >/dev/null
export SOVIEZ_MIG_P20_INJECT_SPLIT_BRAIN=1
die_expect "split brain inject" soviez_migration_split_brain_validate "$auth_id"
unset SOVIEZ_MIG_P20_INJECT_SPLIT_BRAIN
ok "split-brain inject blocks"

# --- Phase 19 drift inject blocks plan/commit ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_INJECT_DRIFT=fingerprint
die_expect "drift blocks plan" soviez_migration_authorization_plan "$PAIR_ID"
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_P20_INJECT_DRIFT=fingerprint
die_expect "drift blocks commit" soviez_migration_authorization_commit "$PAIR_ID" 1
unset SOVIEZ_MIG_P20_INJECT_DRIFT
ok "phase19 drift inject blocks plan and commit"

# --- legacy consume blocked ---
soviez_phase20_fixture_init "$ROOT"
export SOVIEZ_MIG_LEGACY_CONSUME=1
die_expect "legacy consume blocked on plan" soviez_migration_authorization_plan "$PAIR_ID"
unset SOVIEZ_MIG_LEGACY_CONSUME
ok "legacy consume blocked"

# --- cutover/dns flags blocked ---
soviez_phase20_fixture_init "$ROOT"
die_expect "cutover flag blocked" env SOVIEZ_MIG_ALLOW_CUTOVER=1 soviez_migration_authorization_plan "$PAIR_ID"
soviez_phase20_fixture_init "$ROOT"
die_expect "dns cutover flag blocked" env SOVIEZ_MIG_DNS_CUTOVER=1 soviez_migration_authorization_commit "$PAIR_ID" 1
soviez_phase20_fixture_init "$ROOT"
die_expect "source purge flag blocked" env SOVIEZ_MIG_SOURCE_PURGE=1 soviez_migration_authorization_plan "$PAIR_ID"
ok "cutover dns purge flags blocked"

# --- phase21 readiness PASS after activate path ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
act="$(soviez_migration_destination_activate "$PAIR_ID")"
assert_eq "$(soviez_json_get "$act" destination_status)" "production_licensed_pre_cutover" "activate status"
report="$(soviez_migration_phase21_readiness "$auth_id")"
assert_eq "$(soviez_json_get "$report" readiness_status)" "PASS" "phase21 PASS"
ok "phase21 readiness PASS after activate"

# --- offline export/import + replay denial ---
soviez_phase20_fixture_init "$ROOT"
receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$receipt" authorization_id)"
soviez_migration_authorization_export "$auth_id" >/dev/null
pkg_path="$SOVIEZ_MIG_ROOT/offline_packages/pkg-$auth_id.json"
assert_file_exists "$pkg_path"
pkg_copy="$(mktemp "${TMPDIR:-/tmp}/p20-offline-pkg.XXXXXX")".json
cp "$pkg_path" "$pkg_copy"
soviez_phase20_fixture_init "$ROOT"
import_out="$(soviez_migration_authorization_import "$pkg_copy")"
assert_contains "$import_out" '"ok":true' "offline import ok"
set +e
soviez_migration_authorization_import "$pkg_copy" >/dev/null 2>/tmp/p20-replay.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_AUTHORIZATION_REPLAY_DENIED /tmp/p20-replay.err
rm -f "$pkg_copy"
ok "offline export import replay denial"

# --- provider-neutral: manual_grant still eligible ---
soviez_phase20_fixture_init "$ROOT"
soviez_migration_p20_ledger seed \
  --account-id acct-manual \
  --license-id lic-manual \
  --grant-id grant-manual \
  --credits 1 \
  --provider manual_grant \
  --source-fp fp-manual \
  --source-db-uuid dddddddd-dddd-dddd-dddd-dddddddddddd \
  --source-digest sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd >/dev/null
elig="$(soviez_migration_token_eligibility_p20 acct-manual lic-manual)"
assert_eq "$(soviez_json_get "$elig" status)" "eligible" "manual_grant eligible"
assert_eq "$(soviez_json_get "$elig" provider)" "manual_grant" "provider manual_grant"
ok "provider-neutral manual_grant eligible"

# --- multi-tenant isolation (optional second tenant) ---
soviez_phase20_fixture_init "$ROOT" multi
elig_a="$(soviez_migration_token_eligibility_p20 acct-p20 lic-p20)"
elig_b="$(soviez_migration_token_eligibility_p20 acct-b lic-b)"
assert_eq "$(soviez_json_get "$elig_a" status)" "eligible" "tenant a eligible"
assert_eq "$(soviez_json_get "$elig_b" status)" "eligible" "tenant b eligible"
assert_ne "$(soviez_json_get "$elig_a" grant_id)" "$(soviez_json_get "$elig_b" grant_id)" "distinct grant ids"
ok "multi-tenant isolation"

echo "test_phase20_authorization_unit: PASS ($pass_count checks)"
