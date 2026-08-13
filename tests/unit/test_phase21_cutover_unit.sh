#!/usr/bin/env bash
# Phase 21 — unit: cutover plan, preflight, DNS/TLS/nginx, rollback tiers, gates
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase21_fixture.sh
source "$ROOT/tests/helpers/phase21_fixture.sh"
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

die_expect_code() {
  local label="$1"
  local code="$2"
  shift 2
  set +e
  ( set -e; "$@" ) >/dev/null 2>/tmp/p21-die-expect.err
  local rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: $label should fail"; exit 1; }
  grep -q "$code" /tmp/p21-die-expect.err
  ok "$label"
}

# --- plan schema fields present ---
soviez_phase21_fixture_init "$ROOT"
plan="$(soviez_migration_cutover_plan "$PAIR_ID")"
for field in schema plan_id pair_id authorization_id license_id production_fqdn \
  destination_target rollback_window_seconds freeze_max_seconds status traffic_owner \
  production_dns_changed traffic_cutover_started phase21_allowed phase22_allowed; do
  val="$(soviez_json_get "$plan" "$field" 2>/dev/null || true)"
  [[ -n "$val" ]] || { echo "FAIL: plan missing field $field"; exit 1; }
done
assert_eq "$(soviez_json_get "$plan" schema)" "soviez.migration_cutover_plan.v1" "plan schema"
assert_eq "$(soviez_json_get "$plan" status)" "planned" "plan status planned"
assert_eq "$(soviez_json_get "$plan" traffic_owner)" "source" "plan traffic_owner source"
ok "plan schema fields present"

# --- preflight drift inject blocks ---
soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_MIG_P21_INJECT_DRIFT=1
die_expect_code "preflight drift blocks plan" MIGRATION_CUTOVER_DRIFT_DETECTED \
  soviez_migration_cutover_plan "$PAIR_ID"
soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_MIG_P21_INJECT_DRIFT=1
die_expect_code "preflight drift blocks cutover" MIGRATION_CUTOVER_DRIFT_DETECTED \
  soviez_migration_cutover_start "$PAIR_ID" 1
unset SOVIEZ_MIG_P21_INJECT_DRIFT
ok "preflight drift inject blocks"

# --- successful cutover → traffic_owner=destination ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
assert_eq "$(soviez_json_get "$result" current_state)" "cutover_complete" "cutover complete"
assert_eq "$(soviez_json_get "$result" traffic_owner)" "destination" "traffic_owner destination"
auth_id="$(soviez_json_get "$result" authorization_id)"
to="$(soviez_migration_traffic_owner_get "$auth_id")"
assert_eq "$(soviez_json_get "$to" traffic_owner)" "destination" "traffic owner record destination"
ok "successful cutover traffic_owner destination"

# --- source write denial file/enforcement ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
auth_id="$(soviez_json_get "$result" authorization_id)"
op_id="$(soviez_json_get "$result" operation_id)"
soviez_migration_cutover_paths_init
restrict="$(cat "$(soviez_migration_cutover_op_dir "$op_id")/source_restricted.json")"
st="$(soviez_json_get "$restrict" state)"
[[ "$st" == "cutover_maintenance" || "$st" == "cutover_freeze" ]]
die_expect_code "source write denial enforced" MIGRATION_SOURCE_MAINTENANCE_FAILED \
  soviez_migration_source_transition_deny_writes "$auth_id"
ok "source write denial enforcement"

# --- DNS mutate + rollback restores previous ---
soviez_phase21_fixture_init "$ROOT"
fqdn="prod.example.test"
prev="1.2.3.4"
new_target="10.20.30.40"
rec_file="$(soviez_migration_p21_dns_record_file "$fqdn" A)"
mkdir -p "$(dirname "$rec_file")"
printf '%s\n' "$prev" > "$rec_file"
export SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1
soviez_migration_p21_dns_mutate "$fqdn" "$new_target" >/dev/null
assert_eq "$(soviez_migration_p21_dns_snapshot "$fqdn")" "$new_target" "dns mutated"
soviez_migration_p21_dns_rollback "$fqdn" "$prev" >/dev/null
assert_eq "$(soviez_migration_p21_dns_snapshot "$fqdn")" "$prev" "dns rollback restored"
unset SOVIEZ_MIG_P21_CANONICAL_CUTOVER
ok "DNS mutate and rollback"

# --- TLS hostname validation fail inject ---
soviez_phase21_fixture_init "$ROOT"
auth_id="$SOVIEZ_MIG_P21_AUTH_ID"
wrong_fqdn="wrong.example.test"
cert_dir="$(soviez_migration_p21_tls_dir "$auth_id")"
mkdir -p "$cert_dir"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 30 -nodes \
  -keyout "$cert_dir/key.pem" -out "$cert_dir/cert.pem" -subj "/CN=$wrong_fqdn" \
  -addext "subjectAltName=DNS:$wrong_fqdn" >/dev/null 2>&1
export SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1
die_expect_code "TLS hostname validation fail" MIGRATION_TLS_HOSTNAME_MISMATCH \
  soviez_migration_p21_tls_validate "$auth_id" "$SOVIEZ_MIG_P21_FQDN"
unset SOVIEZ_MIG_P21_CANONICAL_CUTOVER
ok "TLS hostname validation fail"

# --- nginx no wildcard ---
soviez_phase21_fixture_init "$ROOT"
tmp_conf="$(mktemp "${TMPDIR:-/tmp}/p21-nginx-wc.XXXXXX")"
printf 'server { listen 443 ssl; server_name *.example.test; }\n' > "$tmp_conf"
set +e
( set -e; soviez_migration_p21_nginx_validate_no_wildcard "$tmp_conf" ) >/dev/null 2>/tmp/p21-wc.err
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: wildcard nginx should fail"; exit 1; }
grep -q MIGRATION_WILDCARD_ROUTE_FORBIDDEN /tmp/p21-wc.err
rm -f "$tmp_conf"
export SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1
die_expect_code "wildcard DNS fqdn forbidden" MIGRATION_WILDCARD_ROUTE_FORBIDDEN \
  soviez_migration_p21_dns_mutate '*.example.test' "1.2.3.4"
unset SOVIEZ_MIG_P21_CANONICAL_CUTOVER
ok "nginx no wildcard"

# --- rollback R0 (pre-commit abort) ---
soviez_phase21_fixture_init "$ROOT"
plan="$(soviez_migration_cutover_plan "$PAIR_ID")"
auth_id="$(soviez_json_get "$plan" authorization_id)"
fake_op="cop-r0-test"
elig="$(soviez_migration_rollback_eligibility "$fake_op" "$auth_id")"
assert_eq "$(soviez_json_get "$elig" tier)" "R0" "rollback tier R0 pre-cutover"
ok "rollback R0 eligibility"

# --- rollback R1 within window ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$result" operation_id)"
auth_id="$(soviez_json_get "$result" authorization_id)"
elig="$(soviez_migration_rollback_eligibility "$op_id" "$auth_id")"
assert_eq "$(soviez_json_get "$elig" tier)" "R1" "rollback tier R1"
rb="$(soviez_migration_rollback_run "$PAIR_ID" "$op_id" "$auth_id" \
  "$(soviez_json_get "$result" fqdn)" "$(soviez_json_get "$result" previous_dns_target)")"
assert_eq "$(soviez_json_get "$rb" tier)" "R1" "rollback run R1"
assert_eq "$(soviez_json_get "$rb" traffic_owner)" "source" "rollback restores source"
ok "rollback R0/R1 works"

# --- R3 with meaningful writes → MIGRATION_ROLLBACK_NOT_SAFE ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$result" operation_id)"
auth_id="$(soviez_json_get "$result" authorization_id)"
export SOVIEZ_MIG_P21_MEANINGFUL_WRITES=1
die_expect_code "rollback R3 not safe" MIGRATION_ROLLBACK_NOT_SAFE \
  soviez_migration_rollback_run "$PAIR_ID" "$op_id" "$auth_id" prod.example.test unset
unset SOVIEZ_MIG_P21_MEANINGFUL_WRITES
ok "rollback R3 meaningful writes blocked"

# --- auto rollback trigger inject ---
soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_MIG_P21_SPLIT_BRAIN=1
trigger="$(soviez_migration_rollback_auto_check "$SOVIEZ_MIG_P21_AUTH_ID")"
assert_eq "$(soviez_json_get "$trigger" trigger)" "AR-04" "AR-04 split brain trigger"
assert_eq "$(soviez_json_get "$trigger" action)" "rollback_required" "rollback required"
unset SOVIEZ_MIG_P21_SPLIT_BRAIN
ok "auto rollback trigger inject"

# --- ALLOW_CUTOVER without P21_CANONICAL blocked ---
soviez_phase21_fixture_init "$ROOT"
export SOVIEZ_MIG_ALLOW_CUTOVER=1
die_expect_code "ALLOW_CUTOVER bypass blocked" MIGRATION_CANONICAL_CUTOVER_REQUIRED \
  soviez_migration_cutover_plan "$PAIR_ID"
unset SOVIEZ_MIG_ALLOW_CUTOVER
ok "ALLOW_CUTOVER without canonical blocked"

# --- purge/archive/saas relay/broad dns blocked ---
for gate in \
  "SOVIEZ_MIG_SOURCE_PURGE:1:MIGRATION_SOURCE_PURGE_NOT_AUTHORIZED:source purge" \
  "SOVIEZ_MIG_SAAS_PAYLOAD_RELAY:1:MIGRATION_DATA_EGRESS_DENIED:saas relay" \
  "SOVIEZ_MIG_SOURCE_ARCHIVE:1:MIGRATION_PHASE22_ARCHIVE_FORBIDDEN:phase22 archive" \
  "SOVIEZ_MIG_BROAD_DNS:1:MIGRATION_BROAD_DNS_FORBIDDEN:broad dns"; do
  IFS=: read -r var val code label <<< "$gate"
  soviez_phase21_fixture_init "$ROOT"
  export "$var=$val"
  die_expect_code "$label forbidden" "$code" soviez_migration_cutover_plan "$PAIR_ID"
  unset "$var"
done
ok "purge archive saas broad dns blocked"

# --- phase22 readiness PASS after cutover; never archives ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$result" operation_id)"
auth_id="$(soviez_json_get "$result" authorization_id)"
soviez_migration_cutover_paths_init
p22="$(cat "$(soviez_migration_cutover_op_dir "$op_id")/phase22_readiness.json")"
assert_eq "$(soviez_json_get "$p22" readiness_status)" "PASS" "phase22 PASS"
assert_eq "$(soviez_json_get "$p22" archives_source)" "False" "phase22 never archives"
assert_eq "$(soviez_json_get "$p22" purges_source)" "False" "phase22 never purges"
ok "phase22 readiness PASS never archives"

# --- token still qty 0 / slot 1 after cutover ---
snap="$(soviez_migration_p20_ledger snapshot --license-id "$SOVIEZ_MIG_P20_LICENSE_ID")"
assert_eq "$(soviez_json_get "$snap" grant_remaining)" "0" "token qty 0 after cutover"
assert_eq "$(soviez_json_get "$snap" slot_count)" "1" "slot 1 after cutover"
ok "token qty 0 slot 1 after cutover"

# --- idempotent retry same op ---
soviez_phase21_fixture_init "$ROOT"
result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
op_id="$(soviez_json_get "$result" operation_id)"
retry="$(soviez_migration_cutover_retry "$op_id")"
assert_eq "$(soviez_json_get "$retry" traffic_owner)" "destination" "retry idempotent destination"
assert_eq "$(soviez_json_get "$retry" current_state)" "cutover_complete" "retry idempotent complete"
ok "idempotent retry same op"

# --- multi-tenant pair isolation (second pair different fqdn) ---
soviez_phase21_fixture_init "$ROOT" multi
auth_a="$SOVIEZ_MIG_P21_AUTH_ID"
PAIR_B="pair-p20-b"
mkdir -p "$(soviez_migration_pair_dir "$PAIR_B")"
SOVIEZ_PAIR="$PAIR_B" python3 - <<PY
import json, os
path = "$(soviez_migration_pair_dir "$PAIR_B")/object.json"
open(path, "w").write(json.dumps({
  "schema": "soviez.migration_pair.v1",
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "license_id": "lic-b",
  "source_production_id": "prod-b",
}, separators=(",", ":")))
PY
export SOVIEZ_MIG_P20_ACCOUNT_ID=acct-b
export SOVIEZ_MIG_P20_LICENSE_ID=lic-b
export SOVIEZ_MIG_P20_SOURCE_FP=fp-source-b
export SOVIEZ_MIG_P20_SOURCE_DB=cccccccc-cccc-cccc-cccc-cccccccccccc
export SOVIEZ_MIG_P20_SOURCE_DIGEST=sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="idem-b-$RANDOM"
receipt_b="$(soviez_migration_authorization_commit "$PAIR_B" 1)"
auth_b="$(soviez_json_get "$receipt_b" authorization_id)"
export SOVIEZ_MIG_P20_AUTH_ID="$auth_b"
export SOVIEZ_MIG_P21_AUTH_ID="$auth_b"
soviez_migration_destination_activate "$PAIR_B" >/dev/null
export SOVIEZ_MIG_P20_ACCOUNT_ID=acct-p20
export SOVIEZ_MIG_P20_LICENSE_ID=lic-p20
export SOVIEZ_MIG_P20_AUTH_ID="$auth_a"
export SOVIEZ_MIG_P21_AUTH_ID="$auth_a"
export SOVIEZ_MIG_P21_FQDN="prod.example.test"
export SOVIEZ_MIG_P21_DEST_IP="10.20.30.40"
result_a="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
fqdn_a="$(soviez_json_get "$result_a" fqdn)"
dest_ip_a="$SOVIEZ_MIG_P21_DEST_IP"
export SOVIEZ_MIG_P20_AUTH_ID="$auth_b"
export SOVIEZ_MIG_P21_AUTH_ID="$auth_b"
export SOVIEZ_MIG_P21_FQDN="tenant-b.example.test"
export SOVIEZ_MIG_P21_DEST_IP="10.99.88.77"
result_b="$(soviez_migration_cutover_start "$PAIR_B" 1)"
assert_eq "$(soviez_json_get "$result_b" fqdn)" "tenant-b.example.test" "tenant b fqdn"
assert_eq "$(soviez_migration_p21_dns_snapshot "tenant-b.example.test")" "10.99.88.77" "tenant b dns"
assert_eq "$(soviez_migration_p21_dns_snapshot "$fqdn_a")" "$dest_ip_a" "tenant a dns unchanged"
assert_ne "$(soviez_migration_p21_dns_snapshot "$fqdn_a")" "$(soviez_migration_p21_dns_snapshot "tenant-b.example.test")" "fqdn dns isolated"
ok "multi-tenant pair isolation"

echo "test_phase21_cutover_unit: PASS ($pass_count checks)"
