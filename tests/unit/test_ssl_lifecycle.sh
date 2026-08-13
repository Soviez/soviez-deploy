#!/usr/bin/env bash
# Phase 12 SSL lifecycle unit tests (isolated disposable fixtures).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p12.XXXXXX")"
soviez_paths_init
soviez_ssl_paths_init

setup_env() {
  local env_id="$1"
  local etype="$2"
  local domain="$3"
  local mode="${4:-public}"
  local rmode="${5:-automatic}"
  local cdir
  cdir="$(soviez_ssl_env_cert_dir "$env_id")"
  mkdir -p "$cdir"
  local lines cert key ca
  lines="$(soviez_ssl_local_issue_fresh "$domain" "$cdir")"
  cert="$(printf '%s\n' "$lines" | sed -n '1p')"
  key="$(printf '%s\n' "$lines" | sed -n '2p')"
  ca="$(printf '%s\n' "$lines" | sed -n '3p')"
  local pca=0
  [[ "$mode" == "private_ca" ]] && pca=1
  SOVIEZ_SSL_ALLOW_PRIVATE_CA="$pca" \
    soviez_ssl_inventory_create "$env_id" "$etype" "$domain" "$cert" "$key" "$ca" "$mode" "fixture" "$rmode" "" "$pca"
}

# --- Policy ---
( soviez_ssl_policy_assert_ca public )
SOVIEZ_SSL_ALLOW_PRIVATE_CA=1 soviez_ssl_policy_assert_ca private_ca
if ( SOVIEZ_SSL_ALLOW_PRIVATE_CA=0 soviez_ssl_policy_assert_ca private_ca ) 2>/dev/null; then
  echo "unapproved private CA should fail" >&2; exit 1
fi
if ( soviez_ssl_policy_assert_ca self_signed ) 2>/dev/null; then
  echo "self-signed should fail" >&2; exit 1
fi
assert_eq "automatic" "$(soviez_ssl_policy_normalize_mode automatic)"

# --- State machine ---
soviez_ssl_sm_assert_transition healthy renewal_window
soviez_ssl_sm_assert_transition renewal_window renewal_scheduled
if soviez_ssl_sm_can_transition healthy certificate_promoting; then
  echo "illegal transition allowed" >&2; exit 1
fi

# --- Inventory + monitoring ---
setup_env prod1 production prod1.example.test public automatic
soviez_ssl_inventory_validate_record prod1
out="$(soviez_ssl_monitor_apply prod1)"
assert_contains "$out" "healthy"

# Self-signed rejection on final acceptance
self="$SOVIEZ_ROOT/self.crt"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$SOVIEZ_ROOT/self.key" -out "$self" -days 1 -subj "/CN=bad.example.test" >/dev/null 2>&1
if ( soviez_ssl_final_acceptance "$self" "" public ) 2>/dev/null; then
  echo "self-signed final acceptance must fail" >&2; exit 1
fi

# --- Permissions ---
setup_env stage1 stage stage1.example.test public automatic
key="$(soviez_json_get "$(soviez_ssl_inventory_read stage1)" private_key_path)"
chmod 644 "$key"
if soviez_ssl_check_permissions x "$key"; then
  echo "world-readable key should fail" >&2; exit 1
fi
chmod 600 "$key"

# --- Backoff ---
assert_eq "21600" "$(soviez_ssl_backoff_seconds 0)"
assert_eq "86400" "$(soviez_ssl_backoff_seconds 4)"
assert_eq "259200" "$(soviez_ssl_backoff_seconds 20)"

# --- Challenge binding / replay ---
op="$(soviez_op_generate_id)"
cid="$(soviez_ssl_challenge_create stage1 stage1.example.test stage1.example.test "$op" public fixture dns-01 "")"
soviez_ssl_challenge_verify_binding "$cid" stage1 stage1.example.test stage1.example.test "$op"
if ( soviez_ssl_challenge_verify_binding "$cid" stage1 other.example.test stage1.example.test "$op" ) 2>/dev/null; then
  echo "wrong domain should fail" >&2; exit 1
fi
soviez_ssl_challenge_consume "$cid"
if ( soviez_ssl_challenge_verify_binding "$cid" stage1 stage1.example.test stage1.example.test "$op" ) 2>/dev/null; then
  echo "replay should fail" >&2; exit 1
fi

# --- Nginx ownership ---
cert="$(soviez_json_get "$(soviez_ssl_inventory_read stage1)" certificate_path)"
key="$(soviez_json_get "$(soviez_ssl_inventory_read stage1)" private_key_path)"
staged="$(soviez_nginx_render_owned stage1 stage1.example.test 127.0.0.1:8069 "$cert" "$key" op1 https)"
soviez_nginx_test_config "$staged"
final="$(soviez_nginx_promote_owned "$staged")"
assert_file_exists "$final"
# Unmanaged file must not be owned
echo 'server { server_name unmanaged; }' > "$SOVIEZ_ROOT/unmanaged.conf"
if soviez_nginx_is_owned "$SOVIEZ_ROOT/unmanaged.conf"; then
  echo "unmanaged marked owned" >&2; exit 1
fi

# --- Renewal modes ---
setup_env n1 production n1.example.test public notify_only
msg="$(soviez_ssl_renew_run n1 0)"
assert_contains "$msg" "notify_only"

setup_env m1 production m1.example.test public manual
if ( soviez_ssl_renew_run m1 0 ) 2>/dev/null; then
  echo "manual without force should fail" >&2; exit 1
fi

# --- Full renewal (fixture ACME) ---
setup_env r1 production r1.example.test public automatic
# Force into renewal window by patching lead_days huge
soviez_ssl_inventory_patch r1 '{"renewal_lead_days": 9000}'
soviez_ssl_renew_run r1 1 >/dev/null
rec="$(soviez_ssl_inventory_read r1)"
assert_eq "healthy" "$(soviez_json_get "$rec" lifecycle_state)"
prev="$(soviez_json_get "$rec" previous_certificate_digest)"
[[ -n "$prev" && "$prev" != "None" && "$prev" != "null" ]] || { echo "previous digest missing" >&2; exit 1; }

# --- Rollback path ---
setup_env rb1 production rb1.example.test public automatic
if ( export SOVIEZ_FORCE_HTTPS_FAIL=1; soviez_ssl_renew_run rb1 1 ) 2>/dev/null; then
  echo "promote fail should not succeed" >&2; exit 1
fi
# Current cert still present
assert_file_exists "$(soviez_json_get "$(soviez_ssl_inventory_read rb1)" certificate_path)"

# --- Duplicate lock ---
setup_env L1 production L1.example.test public automatic
soviez_ssl_acquire_env_lock L1
if ( soviez_ssl_acquire_env_lock L1 ) 2>/dev/null; then
  echo "duplicate lock should fail" >&2; exit 1
fi
soviez_ssl_release_env_lock L1

# --- Temporary HTTP incomplete ---
setup_env th1 production th1.example.test public automatic
marker="$(soviez_ssl_provision_temp_http th1 th1.example.test 2>/dev/null)"
assert_file_exists "$marker"
assert_contains "$(cat "$marker")" "provisioning incomplete"
assert_eq "waiting_for_ssl" "$(soviez_json_get "$(soviez_ssl_inventory_read th1)" readiness_state)"

# --- CLI status ---
out="$(soviez_cmd_ssl_status r1)"
assert_contains "$out" "env=r1"
assert_not_contains "$out" "BEGIN PRIVATE KEY"

# --- Wildcard denied by default ---
if ( SOVIEZ_SSL_ALLOW_WILDCARD=0 soviez_ssl_policy_assert_wildcard 1 ) 2>/dev/null; then
  echo "wildcard should be denied" >&2; exit 1
fi
SOVIEZ_SSL_ALLOW_WILDCARD=1 soviez_ssl_policy_assert_wildcard 1

echo "test_ssl_lifecycle: PASS"
