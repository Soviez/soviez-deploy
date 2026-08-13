#!/usr/bin/env bash
# Phase 17 — Migration discovery / bootstrap / pairing / readiness unit + fixture E2E
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-unit.XXXXXX")"
soviez_paths_init
soviez_ops_paths_init
soviez_migration_paths_init
soviez_device_ensure_keys

PROD="prod-p17-a"
LIC="lic-p17-a"
DIGEST="sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

export SOVIEZ_MIG_FIXTURE_OS_ID="ubuntu:22.04"
export SOVIEZ_MIG_FIXTURE_ARCH="amd64"
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1
export SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1
export SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200 * 1024 * 1024 * 1024))
export SOVIEZ_MIG_FIXTURE_INODES=5000000
export SOVIEZ_MIG_FIXTURE_RAM_MB=8192
export SOVIEZ_MIG_FIXTURE_CPUS=4
export SOVIEZ_MIG_ASSUME_YES=1
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"

export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id":"$PROD",
  "environment_id":"$PROD",
  "license_id":"$LIC",
  "account_id":"acct-p17",
  "database_uuid":"dddddddd-dddd-dddd-dddd-dddddddddddd",
  "image_digest":"$DIGEST",
  "erp_version":"18.0",
  "postgresql_major":"16",
  "docker_version":"24.0",
  "compose_version":"2.20",
  "container_health":"running",
  "postgresql_health":"healthy",
  "domain":"p17.example.test",
  "ssl_status":"valid",
  "backup_health":"healthy",
}))
PY
)"

export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":104857600,"filestore_bytes":52428800,"addon_bytes":10485760,"configuration_bytes":1048576,"file_count":200,"inode_estimate":5000,"estimated_transfer_bytes":168820736,"largest_components":[{"name":"database","bytes":104857600}]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON='{"production_container_health":"running","postgresql_health":"healthy","reverse_proxy_status":"active","domain":"p17.example.test","ssl_status":"valid","ssl_expiry":"2027-01-01T00:00:00Z","maintenance_enabled":false,"active_operations":[],"backup_health":"healthy","update_restore_state":"idle","clock_epoch":0}'
export SOVIEZ_MIG_FIXTURE_ADDONS_JSON='{"addons":[{"name":"soviez_base","version":"1.0"}],"python_packages":["requests==2.31.0"],"system_packages":["nginx"],"external_mounts":[],"configuration_fingerprint":"abc","env_names":["PGHOST","PGUSER"],"integrations":{"mail":true,"payment":false}}'
export SOVIEZ_MIG_FIXTURE_STAGES_JSON
SOVIEZ_MIG_FIXTURE_STAGES_JSON="$(python3 - <<'PY'
import json
print(json.dumps({"stages":[
  {"stage_id":"stage-ok","parent_production_id":"prod-p17-a","image_digest":"sha256:cc","database_bytes":1000,"filestore_bytes":2000,"status":"active","retention_deadline":"2099-01-01","entitlement_state":"ok","domain_ssl_state":"ok","compatibility_state":"ok","owner_selected":False,"selectable":True,"selectable_reason":"ok"},
  {"stage_id":"stage-expired","parent_production_id":"prod-p17-a","image_digest":"sha256:cc","database_bytes":100,"filestore_bytes":100,"status":"expired","retention_deadline":"2020-01-01","entitlement_state":"expired","domain_ssl_state":"none","compatibility_state":"n/a","owner_selected":False,"selectable":False,"selectable_reason":"expired"},
]}))
PY
)"
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":3600,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

pass_count=0
assert_true() { [[ "$1" == "$2" ]] || { echo "FAIL: $3 (got '$1' want '$2')" >&2; exit 1; }; echo "OK: $3"; pass_count=$((pass_count+1)); }

# --- Discovery ---
DISC_OUT="$(soviez_migration_discover_run "$PROD")"
DISC_ID="$(soviez_json_get "$DISC_OUT" discovery_id)"
assert_true "$(soviez_json_get "$DISC_OUT" status)" "completed" "discovery completed"
assert_true "$(soviez_json_get "$DISC_OUT" identity.production_id)" "$PROD" "exact production"
assert_true "$(soviez_json_get "$DISC_OUT" data_transfer_started)" "False" "no transfer"
assert_true "$(soviez_json_get "$DISC_OUT" migration_token_consumed)" "False" "token not consumed"
assert_true "$(soviez_json_get "$DISC_OUT" source_maintenance_enabled)" "False" "no maintenance"

# missing target
if ( soviez_migration_discover_run "" ) 2>/dev/null; then echo "FAIL: empty target"; exit 1; fi
echo "OK: missing target denied"; pass_count=$((pass_count+1))

# wrong target
if ( SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON" soviez_migration_discover_run "wrong-prod" ) 2>/dev/null; then
  echo "FAIL: wrong target"; exit 1
fi
echo "OK: wrong target denied"; pass_count=$((pass_count+1))

# Stage denied via fixture stages dir
mkdir -p "$SOVIEZ_ROOT/stages/stage-as-target"
if declare -F soviez_backup_is_stage_id >/dev/null; then
  export SOVIEZ_STAGES_DIR="$SOVIEZ_ROOT/stages"
  if ( soviez_migration_discover_run "stage-as-target" ) 2>/dev/null; then echo "FAIL stage"; exit 1; fi
  echo "OK: stage target denied"; pass_count=$((pass_count+1))
fi

# Stages unselected
STAGES_OK="$(DISC_OUT="$DISC_OUT" python3 -c 'import json,os; d=json.loads(os.environ["DISC_OUT"]); print(all(not s.get("owner_selected") for s in d["stages"]["stages"]))')"
assert_true "$STAGES_OK" "True" "stages unselected"

# --- Bootstrap ---
BOOT_OUT="$(soviez_migration_bootstrap_run 1)"
BOOT_ID="$(soviez_json_get "$BOOT_OUT" bootstrap_id)"
CODE="$(soviez_json_get "$BOOT_OUT" bootstrap_code)"
assert_true "$(soviez_json_get "$BOOT_OUT" non_sellable)" "True" "non-sellable"
assert_true "$(soviez_json_get "$BOOT_OUT" non_slot_consuming)" "True" "non-slot"
assert_true "$(soviez_json_get "$BOOT_OUT" production_activated)" "False" "not activated"
assert_true "$(soviez_json_get "$BOOT_OUT" migration_token_consumed)" "False" "boot token false"

# unsupported OS
if ( SOVIEZ_MIG_FIXTURE_OS_ID="centos:7" soviez_migration_bootstrap_preflight ) 2>/dev/null; then echo "FAIL os"; exit 1; fi
echo "OK: unsupported OS blocked"; pass_count=$((pass_count+1))

# unsupported arch
if ( SOVIEZ_MIG_FIXTURE_ARCH="arm64" soviez_migration_bootstrap_preflight ) 2>/dev/null; then echo "FAIL arch"; exit 1; fi
echo "OK: arm64 blocked"; pass_count=$((pass_count+1))

# Ubuntu 24.04 ok
SOVIEZ_MIG_FIXTURE_OS_ID="ubuntu:24.04" soviez_migration_bootstrap_preflight >/dev/null
echo "OK: ubuntu 24.04"; pass_count=$((pass_count+1))
export SOVIEZ_MIG_FIXTURE_OS_ID="ubuntu:22.04"

# latest tag refused
BAD_PKG='{"version":"x","digest":"sha256:dead","architecture":"amd64","tag":"latest","signer":"x","expires_at":"2099-01-01T00:00:00Z","signature":"x"}'
if ( soviez_migration_installer_verify "$BAD_PKG" ) 2>/dev/null; then echo "FAIL latest"; exit 1; fi
echo "OK: latest refused"; pass_count=$((pass_count+1))

# bad signature
BAD_SIG="$(python3 - <<'PY'
import json,hmac,hashlib
body={"version":"0.17.0-phase17","digest":"sha256:x","architecture":"amd64","tag":"0.17.0-phase17","signer":"soviez-release","expires_at":"2099-01-01T00:00:00Z"}
canon=json.dumps(body, sort_keys=True, separators=(",",":"))
body["checksum"]="x"
body["signature"]="deadbeef"
print(json.dumps(body))
PY
)"
if ( SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="" soviez_migration_installer_verify "$BAD_SIG" ) 2>/dev/null; then echo "FAIL sig"; exit 1; fi
echo "OK: bad signature refused"; pass_count=$((pass_count+1))

# --- Pairing ---
SRC_FP="$(soviez_json_get "$DISC_OUT" identity.host_identity.fingerprint)"
DST_FP="$(soviez_json_get "$BOOT_OUT" public_fingerprint)"
PAIR_OUT="$(soviez_migration_pair_run "$PROD" "$CODE" "$SRC_FP" "$DST_FP" "$LIC" "$PROD" "$BOOT_ID" 1)"
PAIR_ID="$(soviez_json_get "$PAIR_OUT" migration_pair_id)"
assert_true "$(soviez_json_get "$PAIR_OUT" status)" "trusted" "pair trusted"
assert_true "$(soviez_json_get "$PAIR_OUT" migration_token_consumed)" "False" "pair token false"
assert_true "$(soviez_json_get "$PAIR_OUT" data_transfer_started)" "False" "pair no transfer"
assert_true "$(soviez_json_get "$PAIR_OUT" destination_production_activated)" "False" "dest not activated"

# replay code
if ( soviez_migration_pair_run "$PROD" "$CODE" "$SRC_FP" "$DST_FP" "$LIC" "$PROD" "$BOOT_ID" 1 ) 2>/dev/null; then
  echo "FAIL replay"; exit 1
fi
echo "OK: bootstrap code replay denied"; pass_count=$((pass_count+1))

# wrong fingerprint
BOOT2="$(soviez_migration_bootstrap_run 1)"
CODE2="$(soviez_json_get "$BOOT2" bootstrap_code)"
BOOT2_ID="$(soviez_json_get "$BOOT2" bootstrap_id)"
DST2="$(soviez_json_get "$BOOT2" public_fingerprint)"
if ( soviez_migration_pair_run "$PROD" "$CODE2" "wrongfp" "$DST2" "$LIC" "$PROD" "$BOOT2_ID" 1 ) 2>/dev/null; then
  echo "FAIL fp"; exit 1
fi
echo "OK: fingerprint mismatch denied"; pass_count=$((pass_count+1))

# mTLS material exists
[[ -f "$SOVIEZ_MIG_TRUST_DIR/$PAIR_ID/ca.crt" ]] || { echo "FAIL mtls"; exit 1; }
openssl verify -CAfile "$SOVIEZ_MIG_TRUST_DIR/$PAIR_ID/ca.crt" "$SOVIEZ_MIG_TRUST_DIR/$PAIR_ID/source.crt" >/dev/null
echo "OK: mTLS certs real"; pass_count=$((pass_count+1))

# --- Stage select ---
soviez_migration_stage_select "$PAIR_ID" "stage-ok" select >/dev/null
SEL="$(soviez_json_get "$(cat "$(soviez_migration_pair_dir "$PAIR_ID")/object.json")" selected_stage_ids)"
[[ "$SEL" == *stage-ok* ]] || { echo "FAIL select"; exit 1; }
echo "OK: stage select"; pass_count=$((pass_count+1))
if ( soviez_migration_stage_select "$PAIR_ID" "stage-expired" select ) 2>/dev/null; then echo "FAIL expired select"; exit 1; fi
echo "OK: expired stage denied"; pass_count=$((pass_count+1))
soviez_migration_stage_select "$PAIR_ID" "stage-ok" unselect >/dev/null
echo "OK: stage unselect"; pass_count=$((pass_count+1))

# --- Readiness PASS ---
READY="$(soviez_migration_readiness_run "$PAIR_ID")"
RID="$(soviez_json_get "$READY" report_id)"
assert_true "$(soviez_json_get "$READY" result)" "PASS" "readiness PASS"
assert_true "$(soviez_json_get "$READY" migration_token_consumed)" "False" "ready token false"
assert_true "$(soviez_json_get "$READY" dns_changed)" "False" "dns unchanged"
MARGIN="$(soviez_json_get "$READY" capacity_matrix.margin_pct)"
assert_true "$MARGIN" "25" "25% margin"

# WARNING backup old
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"verified_old","capability_healthy":true,"latest_verified_age_seconds":200000,"restore_tested":false}'
DISC2="$(soviez_migration_discover_run "$PROD")"
# re-bootstrap + pair for warning path
BOOT3="$(soviez_migration_bootstrap_run 1)"
CODE3="$(soviez_json_get "$BOOT3" bootstrap_code)"; BOOT3_ID="$(soviez_json_get "$BOOT3" bootstrap_id)"
SRC3="$(soviez_json_get "$DISC2" identity.host_identity.fingerprint)"
DST3="$(soviez_json_get "$BOOT3" public_fingerprint)"
PAIR3="$(soviez_migration_pair_run "$PROD" "$CODE3" "$SRC3" "$DST3" "$LIC" "$PROD" "$BOOT3_ID" 1)"
PAIR3_ID="$(soviez_json_get "$PAIR3" migration_pair_id)"
READY_W="$(soviez_migration_readiness_run "$PAIR3_ID")"
assert_true "$(soviez_json_get "$READY_W" result)" "WARNING" "readiness WARNING on old backup"

# BLOCKED capacity
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=1000
BOOT4="$(soviez_migration_bootstrap_run 1)"
# restore disk for other tests later
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((200 * 1024 * 1024 * 1024))
CODE4="$(soviez_json_get "$BOOT4" bootstrap_code)"; BOOT4_ID="$(soviez_json_get "$BOOT4" bootstrap_id)"
DST4="$(soviez_json_get "$BOOT4" public_fingerprint)"
# Need discovery with recent backup again
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":100,"restore_tested":true}'
DISC4="$(soviez_migration_discover_run "$PROD")"
SRC4="$(soviez_json_get "$DISC4" identity.host_identity.fingerprint)"
PAIR4="$(soviez_migration_pair_run "$PROD" "$CODE4" "$SRC4" "$DST4" "$LIC" "$PROD" "$BOOT4_ID" 1)"
PAIR4_ID="$(soviez_json_get "$PAIR4" migration_pair_id)"
# Force small disk on readiness by patching bootstrap preflight
python3 - <<PY
import json
p="$SOVIEZ_MIG_BOOTSTRAP_DIR/$BOOT4_ID/object.json"
d=json.load(open(p))
d["preflight"]["available_bytes"]=1000
open(p,"w").write(json.dumps(d, separators=(",",":")))
PY
soviez_migration_sign_object_file "$(soviez_migration_bootstrap_dir "$BOOT4_ID")/object.json"
READY_B="$(soviez_migration_readiness_run "$PAIR4_ID")"
assert_true "$(soviez_json_get "$READY_B" result)" "BLOCKED" "readiness BLOCKED capacity"

# --- Offline ---
OUT_PKG="$SOVIEZ_ROOT/offline-pair.json"
soviez_migration_offline_export pair "$PAIR_ID" "$OUT_PKG" >/dev/null
[[ -f "$OUT_PKG" ]] || { echo "FAIL offline export"; exit 1; }
echo "OK: offline export"; pass_count=$((pass_count+1))
# replay import then second import denied
soviez_migration_offline_import "$OUT_PKG" >/dev/null
if ( soviez_migration_offline_import "$OUT_PKG" ) 2>/dev/null; then echo "FAIL offline replay"; exit 1; fi
echo "OK: offline replay denied"; pass_count=$((pass_count+1))

# --- Abort ---
ABORT="$(soviez_migration_abort_run "$PAIR_ID")"
assert_true "$(soviez_json_get "$ABORT" migration_token_consumed)" "False" "abort token false"
assert_true "$(soviez_json_get "$ABORT" destination_production_activated)" "False" "abort dest false"
# idempotent
soviez_migration_abort_run "$PAIR_ID" >/dev/null
echo "OK: abort idempotent"; pass_count=$((pass_count+1))
[[ -f "$SOVIEZ_MIG_TRUST_DIR/$PAIR_ID/REVOKED" ]] || { echo "FAIL revoke"; exit 1; }
echo "OK: trust revoked"; pass_count=$((pass_count+1))

# Clock skew
if ( soviez_migration_assert_clock_skew $(( $(date -u +%s) + 10000 )) ) 2>/dev/null; then echo "FAIL skew"; exit 1; fi
echo "OK: clock skew blocked"; pass_count=$((pass_count+1))

# Multi-tenant isolation — second prod cannot use first discovery implicitly wrong license
PROD_B="prod-p17-b"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 - <<PY
import json
print(json.dumps({
  "tenant_id":"$PROD_B","environment_id":"$PROD_B","license_id":"lic-p17-b",
  "account_id":"acct-p17b","database_uuid":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "image_digest":"$DIGEST","erp_version":"18.0","postgresql_major":"16",
}))
PY
)"
DISC_B="$(soviez_migration_discover_run "$PROD_B")"
BOOT_B="$(soviez_migration_bootstrap_run 1)"
CODE_B="$(soviez_json_get "$BOOT_B" bootstrap_code)"; BOOT_B_ID="$(soviez_json_get "$BOOT_B" bootstrap_id)"
SRC_B="$(soviez_json_get "$DISC_B" identity.host_identity.fingerprint)"
DST_B="$(soviez_json_get "$BOOT_B" public_fingerprint)"
# Wrong license confirmation
if ( soviez_migration_pair_run "$PROD_B" "$CODE_B" "$SRC_B" "$DST_B" "lic-p17-a" "$PROD_B" "$BOOT_B_ID" 1 ) 2>/dev/null; then
  echo "FAIL cross license"; exit 1
fi
echo "OK: cross-license denied"; pass_count=$((pass_count+1))

echo "phase17 unit: PASS ($pass_count assertions)"
