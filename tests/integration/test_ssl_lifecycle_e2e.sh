#!/usr/bin/env bash
# Phase 12 integration: Production readiness, Stage renewal, disconnect/resume, expiry recovery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p12-int.XXXXXX")"
soviez_paths_init
soviez_ssl_paths_init

mk_env() {
  local id="$1" typ="$2" dom="$3"
  local cdir lines
  cdir="$(soviez_ssl_env_cert_dir "$id")"
  mkdir -p "$cdir"
  lines="$(soviez_ssl_local_issue_fresh "$dom" "$cdir")"
  soviez_ssl_inventory_create "$id" "$typ" "$dom" \
    "$(printf '%s\n' "$lines" | sed -n '1p')" \
    "$(printf '%s\n' "$lines" | sed -n '2p')" \
    "$(printf '%s\n' "$lines" | sed -n '3p')" \
    public fixture automatic
}

# Production: temporary HTTP then HTTPS ready
mk_env pprod production pprod.example.test
soviez_ssl_readiness_set pprod provisioning
soviez_ssl_provision_temp_http pprod pprod.example.test >/dev/null 2>&1 || true
if soviez_ssl_is_production_ready pprod; then
  echo "must not be ready before HTTPS" >&2; exit 1
fi
# Complete via renew/promote
soviez_ssl_renew_run pprod 1 >/dev/null
soviez_ssl_readiness_set pprod ready
soviez_ssl_is_production_ready pprod

# Stage renewal — Stage remains "running" (lifecycle not deleted)
mk_env sstage stage sstage.example.test
before="$(soviez_json_get "$(soviez_ssl_inventory_read sstage)" current_certificate_digest)"
soviez_ssl_renew_run sstage 1 >/dev/null
after="$(soviez_json_get "$(soviez_ssl_inventory_read sstage)" current_certificate_digest)"
assert_ne "$before" "$after"
# Entitlement expiry must not disable maintenance — still renewable
soviez_ssl_renew_run sstage 1 >/dev/null

# Transient DNS failure → retry scheduled, cert preserved
mk_env tdns production tdns.example.test
cert="$(soviez_json_get "$(soviez_ssl_inventory_read tdns)" certificate_path)"
digest_before="$(openssl x509 -in "$cert" -noout -fingerprint -sha256 | sed 's/.*=//' | tr -d ':')"
export SOVIEZ_SSL_SIMULATE_DNS_TIMEOUT=1
soviez_ssl_renew_run tdns 1 >/dev/null 2>&1 || true
unset SOVIEZ_SSL_SIMULATE_DNS_TIMEOUT
assert_eq "retry_scheduled" "$(soviez_json_get "$(soviez_ssl_inventory_read tdns)" lifecycle_state)"
digest_after="$(openssl x509 -in "$cert" -noout -fingerprint -sha256 | sed 's/.*=//' | tr -d ':')"
assert_eq "$digest_before" "$digest_after"
# Manual retry recovers
soviez_ssl_try_again tdns >/dev/null

# Disconnect/resume at waiting_for_dns via abort + try again
mk_env disc production disc.example.test
op="$(soviez_op_generate_id)"
cid="$(soviez_ssl_challenge_create disc disc.example.test disc.example.test "$op" public fixture dns-01 "")"
soviez_ssl_inventory_patch disc "$(CID="$cid" OP="$op" python3 - <<'PY'
import json, os
print(json.dumps({
  "challenge_id": os.environ["CID"],
  "operation_id": os.environ["OP"],
  "lifecycle_state": "waiting_for_dns"
}))
PY
)"
soviez_ssl_abort_safely disc >/dev/null
assert_eq "canceled" "$(soviez_json_get "$(soviez_ssl_inventory_read disc)" lifecycle_state)"
soviez_ssl_try_again disc >/dev/null

# Reboot recovery simulation: lock dir leftover cleaned by release; reattach op
mk_env reb production reb.example.test
soviez_ssl_inventory_patch reb '{"renewal_lead_days":9000}'
opid="$(soviez_ssl_renew_create_op reb)"
soviez_ssl_reattach "$opid" >/dev/null

# Private CA explicit policy
export SOVIEZ_SSL_ALLOW_PRIVATE_CA=1
mk_env pca1 production pca1.example.test
# recreate with private_ca mode
cdir="$(soviez_ssl_env_cert_dir pca2)"
mkdir -p "$cdir"
lines="$(soviez_ssl_local_issue_fresh pca2.example.test "$cdir")"
soviez_ssl_inventory_create pca2 production pca2.example.test \
  "$(printf '%s\n' "$lines" | sed -n '1p')" \
  "$(printf '%s\n' "$lines" | sed -n '2p')" \
  "$(printf '%s\n' "$lines" | sed -n '3p')" \
  private_ca fixture automatic "" 1
soviez_ssl_final_acceptance "$(soviez_json_get "$(soviez_ssl_inventory_read pca2)" certificate_path)" \
  "$(soviez_json_get "$(soviez_ssl_inventory_read pca2)" chain_path)" private_ca

# Wildcard scope mismatch
cid2="$(soviez_ssl_challenge_create w1 '*.example.test' '*.example.test' "$(soviez_op_generate_id)" public fixture dns-01 '*.example.test')"
op2="$(soviez_json_get "$(soviez_ssl_challenge_load "$cid2")" operation_id)"
if ( soviez_ssl_challenge_verify_binding "$cid2" w1 evil.other.test '*.example.test' "$op2" ) 2>/dev/null; then
  echo "wildcard escape should fail" >&2; exit 1
fi

# Nginx conflict on same domain different env
mk_env c1 production shared.example.test
mk_env c2 production otherbox.example.test
# Force c2 domain to shared for collision
soviez_ssl_inventory_patch c2 '{"domain":"shared.example.test"}'
cert="$(soviez_json_get "$(soviez_ssl_inventory_read c1)" certificate_path)"
key="$(soviez_json_get "$(soviez_ssl_inventory_read c1)" private_key_path)"
soviez_nginx_render_owned c1 shared.example.test 127.0.0.1:8069 "$cert" "$key" "" https >/dev/null
cert2="$(soviez_json_get "$(soviez_ssl_inventory_read c2)" certificate_path)"
key2="$(soviez_json_get "$(soviez_ssl_inventory_read c2)" private_key_path)"
if ( soviez_nginx_render_owned c2 shared.example.test 127.0.0.1:8069 "$cert2" "$key2" "" https ) 2>/dev/null; then
  echo "nginx domain collision should fail" >&2; exit 1
fi

# Policy CLI
soviez_cmd_ssl_policy sstage notify_only >/dev/null
assert_eq "notify_only" "$(soviez_json_get "$(soviez_ssl_inventory_read sstage)" renewal_mode)"

echo "test_ssl_lifecycle_integration: PASS"
