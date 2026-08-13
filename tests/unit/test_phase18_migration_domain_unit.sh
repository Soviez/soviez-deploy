#!/usr/bin/env bash
# Phase 18 — Migration domain / DNS / landing / TLS / routing unit tests
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p18-unit.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init
soviez_ops_paths_init
soviez_migration_paths_init
soviez_device_ensure_keys

PROD="prod-p18-a"
LIC="lic-p18-a"
PROD_DOMAIN="p18.example.test"
MIG_DOMAIN="migrate.${PROD_DOMAIN}"
DIGEST="sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

export SOVIEZ_MIG_DNS_ZONE_DIR="$SOVIEZ_ROOT/dns_zone"
mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
printf 'owner-marker\n' > "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt"

export SOVIEZ_MIG_FIXTURE_OS_ID="ubuntu:22.04"
export SOVIEZ_MIG_FIXTURE_ARCH="amd64"
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200 * 1024 * 1024 * 1024))
export SOVIEZ_MIG_FIXTURE_INODES=5000000
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"

export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id":"$PROD","environment_id":"$PROD","license_id":"$LIC",
  "database_uuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","image_digest":"$DIGEST",
  "domain":"$PROD_DOMAIN","erp_version":"18.0","postgresql_major":"16",
}))
PY
)"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1048576,"filestore_bytes":524288,"addon_bytes":1024,"configuration_bytes":1024,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2000000,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$PROD_DOMAIN\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":100,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'
export SOVIEZ_MIG_FIXTURE_HEALTH_JSON='{"source_maintenance_enabled":false,"dns_changed":false,"data_transfer_started":false,"disruption_detected":false}'

pass_count=0
assert_true() { [[ "$1" == "$2" ]] || { echo "FAIL: $3 (got '$1' want '$2')" >&2; exit 1; }; echo "OK: $3"; pass_count=$((pass_count+1)); }

# Phase 17 baseline pair
DISC="$(soviez_migration_discover_run "$PROD")"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"
BOOT_ID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC_FP="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST_FP="$(soviez_json_get "$BOOT" public_fingerprint)"
PAIR="$(soviez_migration_pair_run "$PROD" "$CODE" "$SRC_FP" "$DST_FP" "$LIC" "$PROD" "$BOOT_ID" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"

# --- Domain plan ---
PLAN="$(soviez_migration_domain_plan_run "$PAIR_ID")"
PLAN_ID="$(soviez_json_get "$PLAN" plan_id)"
assert_true "$(soviez_json_get "$PLAN" migration_fqdn)" "$MIG_DOMAIN" "default migrate subdomain"
assert_true "$(soviez_json_get "$PLAN" production_domain_mutation_allowed)" "False" "no prod mutation"
assert_true "$(soviez_json_get "$PLAN" payload_transfer_allowed)" "False" "no transfer in plan"
assert_true "$(soviez_json_get "$PLAN" migration_token_consumed)" "False" "token not consumed plan"
assert_true "$(soviez_json_get "$PLAN" destination_production_activated)" "False" "dest not activated plan"

# production domain denied
if ( soviez_migration_domain_assert_migration_fqdn "$PROD_DOMAIN" "$PROD_DOMAIN" ) 2>/dev/null; then
  echo "FAIL: production domain as migration"; exit 1
fi
echo "OK: production domain denied"; pass_count=$((pass_count+1))

# wildcard denied
if ( soviez_migration_domain_assert_migration_fqdn "*.bad.example.test" "$PROD_DOMAIN" ) 2>/dev/null; then
  echo "FAIL: wildcard"; exit 1
fi
echo "OK: wildcard denied"; pass_count=$((pass_count+1))

# source fingerprint stable
INS="$(soviez_migration_source_inspection_run "$PAIR")"
FP1="$(soviez_json_get "$INS" source_routing_fingerprint)"
INS2="$(soviez_migration_source_inspection_run "$PAIR")"
FP2="$(soviez_json_get "$INS2" source_routing_fingerprint)"
assert_true "$FP1" "$FP2" "source fingerprint stable"
[[ -n "$FP1" ]] || { echo "FAIL: empty fingerprint"; exit 1; }
echo "OK: fingerprint non-empty"; pass_count=$((pass_count+1))

# --- DNS challenge ---
CH="$(soviez_migration_dns_challenge_create "$PAIR_ID" "$PLAN_ID")"
CH_ID="$(soviez_json_get "$CH" challenge_id)"
TXT_NAME="$(soviez_json_get "$(soviez_json_get "$CH" txt_record)" name)"
TXT_VAL="$(soviez_json_get "$(soviez_json_get "$CH" txt_record)" value)"
assert_true "$TXT_NAME" "_soviez-migration.${MIG_DOMAIN}" "txt record name"

# signature binding
PAYLOAD="$(soviez_json_get "$CH" binding_payload)"
SIG="$(soviez_json_get "$CH" binding_signature)"
soviez_migration_dns_challenge_verify_sig "$PAYLOAD" "$SIG" || { echo "FAIL sig"; exit 1; }
echo "OK: challenge sign verify"; pass_count=$((pass_count+1))

# install fixture DNS records
soviez_migration_dns_provider_create_record "$TXT_NAME" TXT "$TXT_VAL" 300 >/dev/null
soviez_migration_dns_provider_create_record "$MIG_DOMAIN" A "203.0.113.10" 300 >/dev/null

VERIFIED="$(soviez_migration_dns_challenge_verify "$CH_ID")"
assert_true "$(soviez_json_get "$VERIFIED" status)" "verified" "dns challenge verified"

# replay denied
if ( soviez_migration_dns_challenge_verify "$CH_ID" ) 2>/dev/null; then echo "FAIL replay"; exit 1; fi
echo "OK: challenge replay denied"; pass_count=$((pass_count+1))

# expiry denied (renew creates new challenge)
CH2="$(soviez_migration_dns_challenge_renew "$PAIR_ID")"
CH2_ID="$(soviez_json_get "$CH2" challenge_id)"
TXT2="$(soviez_json_get "$(soviez_json_get "$CH2" txt_record)" value)"
TXT2N="$(soviez_json_get "$(soviez_json_get "$CH2" txt_record)" name)"
soviez_migration_dns_provider_create_record "$TXT2N" TXT "$TXT2" 300 >/dev/null
python3 - <<PY
import json
p="$SOVIEZ_MIG_DNS_CHALLENGE_DIR/$CH2_ID/object.json"
d=json.load(open(p))
d["expires_at"]="2000-01-01T00:00:00Z"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
if ( soviez_migration_dns_challenge_verify "$CH2_ID" ) 2>/dev/null; then echo "FAIL expiry"; exit 1; fi
echo "OK: challenge expiry denied"; pass_count=$((pass_count+1))

# renew creates a new challenge id
CH3="$(soviez_migration_dns_challenge_renew "$PAIR_ID")"
CH3_ID="$(soviez_json_get "$CH3" challenge_id)"
[[ "$CH3_ID" != "$CH2_ID" ]] || { echo "FAIL renew new id"; exit 1; }
echo "OK: dns renew new challenge"; pass_count=$((pass_count+1))

# try-again same id after records published
TN3="$(soviez_json_get "$(soviez_json_get "$CH3" txt_record)" name)"
TV3="$(soviez_json_get "$(soviez_json_get "$CH3" txt_record)" value)"
soviez_migration_dns_provider_create_record "$TN3" TXT "$TV3" 300 >/dev/null
soviez_migration_dns_provider_create_record "$MIG_DOMAIN" A "203.0.113.10" 300 >/dev/null
TRY="$(soviez_migration_dns_challenge_try_again "$CH3_ID")"
assert_true "$(soviez_json_get "$TRY" challenge_id)" "$CH3_ID" "try-again same challenge id"
assert_true "$(soviez_json_get "$TRY" status)" "verified" "try-again verified"
TRY2="$(soviez_migration_dns_challenge_try_again "$CH3_ID")"
assert_true "$(soviez_json_get "$TRY2" try_again)" "already_verified" "try-again idempotent"
echo "OK: try-again idempotent"; pass_count=$((pass_count+1))

# --- Landing ---
LAND_JSON="$(soviez_migration_landing_prepare "$PAIR_ID")"
SITE_ID="$(soviez_json_get "$LAND_JSON" site_id)"
SITE_DIR="$(soviez_migration_landing_site_dir "$SITE_ID")"
[[ -f "$SITE_DIR/www/index.html" ]] || { echo "FAIL landing html"; exit 1; }
echo "OK: landing html"; pass_count=$((pass_count+1))
[[ -f "$SITE_DIR/www/healthz" ]] || { echo "FAIL healthz"; exit 1; }
echo "OK: landing healthz"; pass_count=$((pass_count+1))
if grep -q "server_name[[:space:]]*${PROD_DOMAIN}" "$SITE_DIR/nginx.conf"; then
  echo "FAIL production server_name"; exit 1
fi
echo "OK: landing no production server_name"; pass_count=$((pass_count+1))
grep -q "server_name[[:space:]]*${MIG_DOMAIN}" "$SITE_DIR/nginx.conf" || { echo "FAIL mig server_name"; exit 1; }
echo "OK: landing migration server_name"; pass_count=$((pass_count+1))

# --- TLS ---
TLS_INV="$(soviez_migration_tls_prepare "$PAIR_ID" "$MIG_DOMAIN")"
assert_true "$(soviez_json_get "$TLS_INV" fqdn)" "$MIG_DOMAIN" "tls fqdn"
assert_true "$(soviez_json_get "$TLS_INV" private_key_included)" "False" "inventory no private key"
CERT_PATH="$(soviez_json_get "$TLS_INV" certificate_path)"
soviez_migration_tls_verify_cert "$CERT_PATH" "$MIG_DOMAIN"
echo "OK: tls fixture issued"; pass_count=$((pass_count+1))

if ( soviez_migration_tls_policy_assert "$MIG_DOMAIN" "$PROD_DOMAIN" "self_signed" ) 2>/dev/null; then
  echo "FAIL self-signed"; exit 1
fi
echo "OK: self-signed final denied"; pass_count=$((pass_count+1))

# verify challenge for routing (fresh)
CH4="$(soviez_migration_dns_challenge_renew "$PAIR_ID")"
CH4_ID="$(soviez_json_get "$CH4" challenge_id)"
TV4="$(soviez_json_get "$(soviez_json_get "$CH4" txt_record)" value)"
TN4="$(soviez_json_get "$(soviez_json_get "$CH4" txt_record)" name)"
soviez_migration_dns_provider_create_record "$TN4" TXT "$TV4" 300 >/dev/null
soviez_migration_dns_provider_create_record "$MIG_DOMAIN" A "203.0.113.10" 300 >/dev/null
soviez_migration_dns_challenge_verify "$CH4_ID" >/dev/null

# --- Routing PASS ---
ROUTE="$(soviez_migration_routing_readiness_run "$PAIR_ID")"
RPLAN_ID="$(soviez_json_get "$ROUTE" plan_id)"
assert_true "$(soviez_json_get "$ROUTE" result)" "PASS" "routing PASS"
assert_true "$(soviez_json_get "$ROUTE" cutover_authorized)" "False" "no cutover"
assert_true "$(soviez_json_get "$ROUTE" migration_token_consumed)" "False" "routing token false"

# assert_no_transfer / cutover deny
if ( SOVIEZ_MIG_ALLOW_TRANSFER=1 soviez_migration_assert_no_transfer ) 2>/dev/null; then echo "FAIL transfer"; exit 1; fi
echo "OK: transfer denied"; pass_count=$((pass_count+1))
if ( SOVIEZ_MIG_ALLOW_CUTOVER=1 soviez_migration_assert_no_transfer ) 2>/dev/null; then echo "FAIL cutover"; exit 1; fi
echo "OK: cutover denied"; pass_count=$((pass_count+1))

# source guards
if ( SOVIEZ_MIG_SOURCE_MUTATION=1 soviez_migration_routing_assert_no_source_mutation ) 2>/dev/null; then echo "FAIL source mut"; exit 1; fi
echo "OK: source mutation guard"; pass_count=$((pass_count+1))

# domain abort preserves owner marker
[[ -f "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt" ]] || { echo "FAIL marker pre"; exit 1; }
ABORT="$(soviez_migration_domain_abort "$PAIR_ID")"
assert_true "$(soviez_json_get "$ABORT" owner_dns_preserved)" "True" "owner dns preserved"
[[ -f "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt" ]] || { echo "FAIL marker post"; exit 1; }
echo "OK: abort preserves owner DNS marker"; pass_count=$((pass_count+1))
[[ ! -d "$SITE_DIR" ]] || { echo "FAIL landing cleaned"; exit 1; }
echo "OK: landing cleaned on abort"; pass_count=$((pass_count+1))

# instructions export
INST="$SOVIEZ_ROOT/dns-inst.json"
soviez_migration_dns_instructions_export "$CH4_ID" "$INST" >/dev/null
[[ -f "$INST" ]] || { echo "FAIL instructions"; exit 1; }
echo "OK: dns instructions export"; pass_count=$((pass_count+1))

# routing show + drift
soviez_migration_routing_plan_show "$RPLAN_ID" >/dev/null
echo "OK: routing plan show"; pass_count=$((pass_count+1))

echo "phase18 unit: PASS ($pass_count assertions)"
