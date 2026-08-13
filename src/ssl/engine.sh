# shellcheck shell=bash
# Phase 12 durable SSL renewal engine (extends operations foundation).

soviez_ssl_renew_create_op() {
  local env_id="$1"
  local op_id
  op_id="$(soviez_op_create)"
  local state_file
  state_file="$(soviez_operation_state_file "$op_id")"
  soviez_json_merge_file "$state_file" "$(python3 - <<PY
import json
print(json.dumps({
  "kind": "ssl_renewal",
  "environment_id": "$env_id",
  "ssl_state": "renewal_scheduled",
  "state": "renewal_scheduled"
}))
PY
)"
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    soviez_ops_sync_transition "$op_id" ssl_renewal "$env_id" "renewal_scheduled" "created" "{}" "$state_file" \
      || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_FAILED
  fi
  printf '%s\n' "$op_id"
}

soviez_ssl_op_mark() {
  local op_id="$1" ssl_state="$2" env_id="${3:-}"
  local state_file
  state_file="$(soviez_operation_state_file "$op_id")"
  [[ -f "$state_file" ]] || return 0
  soviez_json_merge_file "$state_file" "$(SOVIEZ_S="$ssl_state" python3 - <<'PY'
import json, os, time
print(json.dumps({"ssl_state": os.environ["SOVIEZ_S"], "state": os.environ["SOVIEZ_S"],
  "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, separators=(",",":")))
PY
)"
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    [[ -n "$env_id" ]] || env_id="$(soviez_json_get "$(cat "$state_file")" environment_id 2>/dev/null || true)"
    soviez_ops_sync_transition "$op_id" ssl_renewal "$env_id" "$ssl_state" "transition" "{}" "$state_file" \
      || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_PENDING
  fi
}

soviez_ssl_renew_run() {
  local env_id="$1"
  local force="${2:-0}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "environment id required"

  soviez_ssl_inventory_validate_record "$env_id"
  local rec mode days_out state code days
  rec="$(soviez_ssl_inventory_read "$env_id")"
  mode="$(soviez_json_get "$rec" renewal_mode)"

  if [[ "$mode" == "manual" && "$force" != "1" ]]; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_RENEWAL_DISABLED" "Renewal mode is manual; use --ssl-renew with explicit confirm"
  fi
  if [[ "$mode" == "notify_only" && "$force" != "1" ]]; then
    soviez_ssl_monitor_apply "$env_id" >/dev/null
    soviez_ssl_inventory_patch "$env_id" '{"lifecycle_state":"renewal_window"}'
    printf 'notify_only: renewal due reported; no issuance performed\n'
    return 0
  fi

  # Due check unless force
  days_out="$(soviez_ssl_monitor_env "$env_id")"
  state="$(printf '%s\n' "$days_out" | sed -n '1p')"
  code="$(printf '%s\n' "$days_out" | sed -n '2p')"
  days="$(printf '%s\n' "$days_out" | sed -n '3p')"
  if [[ "$force" != "1" && "$state" == "healthy" ]]; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_RENEWAL_NOT_DUE" "Certificate not in renewal window (days=$days)"
  fi

  soviez_ssl_acquire_env_lock "$env_id"
  local op_id domain provider cert_mode upstream
  op_id="$(soviez_ssl_renew_create_op "$env_id")"
  domain="$(soviez_json_get "$rec" domain)"
  provider="$(soviez_json_get "$rec" acme_provider)"
  cert_mode="$(soviez_json_get "$rec" certificate_mode)"
  upstream="${SOVIEZ_SSL_UPSTREAM:-127.0.0.1:8069}"

  trap 'soviez_ssl_release_env_lock "'"$env_id"'"' RETURN

  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<PY
import json, time
print(json.dumps({
  "lifecycle_state": "renewal_authorizing",
  "operation_id": "$op_id",
  "last_renewal_attempt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
}))
PY
)"

  # Challenge
  local challenge_id
  challenge_id="$(soviez_ssl_challenge_create "$env_id" "$domain" "$domain" "$op_id" "$cert_mode" "$provider" "dns-01" "")"
  soviez_ssl_inventory_patch "$env_id" "$(CID="$challenge_id" python3 - <<'PY'
import json, os
print(json.dumps({"challenge_id": os.environ["CID"], "lifecycle_state": "waiting_for_dns"}))
PY
)"
  soviez_ssl_op_mark "$op_id" "waiting_for_dns" "$env_id"

  if [[ "${SOVIEZ_SSL_SIMULATE_DNS_TIMEOUT:-0}" == "1" ]]; then
    soviez_ssl_op_mark "$op_id" "retry_scheduled" "$env_id"
    soviez_ssl_renew_fail_retryable "$env_id" "$op_id" "$SOVIEZ_SSL_CODE_DNS_WAIT_TIMEOUT"
    return 1
  fi

  # Fixture: DNS OK immediately in test / when SOVIEZ_STAGE_DNS_OK / SOVIEZ_SSL_DNS_OK
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" || "${SOVIEZ_SSL_DNS_OK:-1}" == "1" ]]; then
    soviez_ssl_challenge_verify_binding "$challenge_id" "$env_id" "$domain" "$domain" "$op_id"
    soviez_ssl_challenge_consume "$challenge_id"
  else
    soviez_ssl_renew_fail_retryable "$env_id" "$op_id" "$SOVIEZ_SSL_CODE_DNS_WAIT_TIMEOUT"
    return 1
  fi

  # Issue into staging
  local stage_dir
  stage_dir="$SOVIEZ_SSL_STAGING_DIR/${op_id}"
  mkdir -p "$stage_dir"
  chmod 700 "$stage_dir"
  local scert skey schain
  scert="$stage_dir/server.crt"
  skey="$stage_dir/server.key"
  schain="$stage_dir/chain.crt"

  if [[ "${SOVIEZ_SSL_SIMULATE_ACME_FAIL:-0}" == "1" ]]; then
    soviez_ssl_renew_fail_retryable "$env_id" "$op_id" "$SOVIEZ_SSL_CODE_ACME_PROVIDER_UNAVAILABLE"
    return 1
  fi

  local use_provider="$provider"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    use_provider="fixture"
  fi
  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<'PY'
import json
print(json.dumps({"lifecycle_state": "certificate_issuing"}))
PY
)"
  soviez_ssl_provider_issue "$use_provider" "$domain" "$scert" "$skey" "$schain"
  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<'PY'
import json
print(json.dumps({"lifecycle_state": "certificate_received"}))
PY
)"

  if [[ "${SOVIEZ_FORCE_HTTPS_FAIL:-0}" == "1" || "${SOVIEZ_SSL_SIMULATE_PROMOTE_FAIL:-0}" == "1" ]]; then
    # Exercise rollback path: validate may pass then https fail
    export SOVIEZ_FORCE_HTTPS_FAIL=1
  fi

  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<'PY'
import json
print(json.dumps({"lifecycle_state": "certificate_promoting"}))
PY
)"
  soviez_ssl_op_mark "$op_id" "certificate_promoting" "$env_id"
  if ! soviez_ssl_promote "$env_id" "$scert" "$skey" "$schain" "$upstream" "$op_id"; then
    soviez_ssl_op_mark "$op_id" "rollback_running" "$env_id"
    soviez_ssl_renew_fail_retryable "$env_id" "$op_id" "$SOVIEZ_SSL_CODE_CERTIFICATE_PROMOTION_FAILED"
    return 1
  fi

  # Mark op complete without Production SM transition (ssl ops use ssl_state).
  soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
    '{"ssl_state":"completed","state":"completed"}'
  if declare -F soviez_ops_sync_terminal >/dev/null 2>&1; then
    soviez_ops_sync_terminal "$op_id" ssl_renewal "$env_id" completed "$(soviez_operation_state_file "$op_id")" \
      || soviez_ops_sync_mark_pending "$op_id" OPERATION_TERMINAL_SYNC_INCOMPLETE
  fi
  printf 'ssl_renewal completed op=%s env=%s\n' "$op_id" "$env_id"
}

soviez_ssl_renew_fail_retryable() {
  local env_id="$1"
  local op_id="$2"
  local code="$3"
  local rec retry next
  rec="$(soviez_ssl_inventory_read "$env_id")"
  retry="$(soviez_json_get "$rec" retry_count)"
  [[ -n "$retry" ]] || retry=0
  next="$(soviez_ssl_backoff_next_iso "$retry")"
  retry=$((retry + 1))
  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<PY
import json
print(json.dumps({
  "lifecycle_state": "retry_scheduled",
  "readiness_state": "needs_action",
  "last_failure_code": "$code",
  "retry_count": $retry,
  "next_scheduled_attempt": "$next",
  "operation_id": "$op_id"
}))
PY
)"
  # Preserve current certificate — never delete on failure
  printf 'SSL_DENIAL code=%s message=retry_scheduled next=%s\n' "$code" "$next" >&2
}

soviez_ssl_repair() {
  local env_id="$1"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "environment id required"
  # Repair = force renewal attempt; never stops ERP
  soviez_ssl_renew_run "$env_id" 1
}

soviez_ssl_reattach() {
  local op_id="$1"
  [[ -n "$op_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "operation id required"
  local state_file env_id ssl_state
  state_file="$(soviez_operation_state_file "$op_id")"
  [[ -f "$state_file" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "operation not found"
  local body
  body="$(cat "$state_file")"
  env_id="$(soviez_json_get "$body" environment_id)"
  ssl_state="$(soviez_json_get "$body" ssl_state 2>/dev/null || echo unknown)"
  printf 'reattach op=%s env=%s ssl_state=%s\n' "$op_id" "$env_id" "$ssl_state"
  # Resume by force renew if not completed
  if [[ "$ssl_state" != "completed" ]]; then
    soviez_ssl_renew_run "$env_id" 1
  fi
}

soviez_ssl_try_again() {
  local env_id="$1"
  soviez_ssl_renew_run "$env_id" 1
}

soviez_ssl_abort_safely() {
  local env_id="$1"
  local rec cid
  rec="$(soviez_ssl_inventory_read "$env_id")"
  cid="$(soviez_json_get "$rec" challenge_id)"
  if [[ -n "$cid" && "$cid" != "None" && "$cid" != "null" ]]; then
    soviez_ssl_challenge_abort "$cid"
  fi
  soviez_ssl_release_env_lock "$env_id"
  soviez_ssl_inventory_patch "$env_id" '{"lifecycle_state":"canceled","challenge_id":null,"operation_id":null}'
  printf 'aborted safely; current certificate preserved\n'
}
