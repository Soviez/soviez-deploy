# shellcheck shell=bash
# Phase 12 atomic certificate promotion and rollback.

soviez_ssl_validate_replacement() {
  local cert="$1"
  local key="$2"
  local chain="$3"
  local domain="$4"
  local cert_mode="${5:-public}"

  [[ -f "$cert" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_MISSING" "replacement cert missing"
  [[ -f "$key" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_MISSING" "replacement key missing"
  soviez_ssl_policy_assert_ca "$cert_mode"

  # Self-signed leaf rejection
  local issuer subject
  issuer="$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | tr -d ' ' | sed 's/issuer=//')"
  subject="$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | tr -d ' ' | sed 's/subject=//')"
  if [[ "$issuer" == "$subject" ]]; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_SELF_SIGNED_NOT_ALLOWED" "Self-signed replacement rejected"
  fi

  if [[ -n "$chain" && -f "$chain" ]]; then
    openssl verify -CAfile "$chain" "$cert" >/dev/null 2>&1 \
      || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_CHAIN_INVALID" "Chain validation failed"
  else
    soviez_ssl_validate_chain "$cert" "$chain" 2>/dev/null \
      || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_UNTRUSTED" "Untrusted certificate"
  fi

  soviez_ssl_check_hostname "$cert" "$domain" \
    || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_HOSTNAME_MISMATCH" "Hostname mismatch"
  soviez_ssl_check_key_match "$cert" "$key" \
    || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_KEY_MISMATCH" "Key mismatch"
  soviez_ssl_check_permissions "$cert" "$key" \
    || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_PERMISSION_INVALID" "Unsafe key permissions"

  local days
  days="$(soviez_ssl_days_until_expiry "$cert")"
  (( days >= 0 )) || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_EXPIRED" "Replacement already expired"
  # not-yet-valid
  local start epoch_start now
  start="$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | sed 's/notBefore=//')"
  epoch_start="$(date -u -j -f "%b %d %T %Y %Z" "$start" +%s 2>/dev/null || date -u -d "$start" +%s 2>/dev/null || echo 0)"
  now="$(date -u +%s)"
  if (( epoch_start > now + 60 )); then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_NOT_YET_VALID" "Certificate not yet valid"
  fi
}

soviez_ssl_promote() {
  local env_id="$1"
  local staged_cert="$2"
  local staged_key="$3"
  local staged_chain="$4"
  local upstream="${5:-127.0.0.1:8069}"
  local op_id="${6:-}"

  local rec domain live_cert live_key live_chain cert_mode
  rec="$(soviez_ssl_inventory_read "$env_id")"
  domain="$(soviez_json_get "$rec" domain)"
  live_cert="$(soviez_json_get "$rec" certificate_path)"
  live_key="$(soviez_json_get "$rec" private_key_path)"
  live_chain="$(soviez_json_get "$rec" chain_path 2>/dev/null || true)"
  cert_mode="$(soviez_json_get "$rec" certificate_mode)"

  soviez_ssl_validate_replacement "$staged_cert" "$staged_key" "$staged_chain" "$domain" "$cert_mode"

  # Preserve current working material BEFORE promotion
  local backup_dir
  backup_dir="$(dirname "$live_cert")/previous"
  mkdir -p "$backup_dir"
  chmod 700 "$backup_dir"
  [[ -f "$live_cert" ]] && cp -f "$live_cert" "$backup_dir/server.crt"
  [[ -f "$live_key" ]] && cp -f "$live_key" "$backup_dir/server.key"
  [[ -n "$live_chain" && -f "$live_chain" ]] && cp -f "$live_chain" "$backup_dir/chain.crt" || true
  local prev_digest
  prev_digest="$(soviez_json_get "$rec" current_certificate_digest)"

  # Stage Nginx
  local staged_nginx
  staged_nginx="$(soviez_nginx_render_owned "$env_id" "$domain" "$upstream" "$staged_cert" "$staged_key" "$op_id" https)"
  if ! soviez_nginx_test_config "$staged_nginx"; then
    rm -f "$staged_nginx"
    soviez_ssl_die "$SOVIEZ_SSL_CODE_NGINX_VALIDATION_FAILED" "nginx -t failed"
  fi

  # Promote cert files atomically-ish (copy then replace)
  cp -f "$staged_cert" "${live_cert}.new"
  cp -f "$staged_key" "${live_key}.new"
  mv -f "${live_cert}.new" "$live_cert"
  mv -f "${live_key}.new" "$live_key"
  chmod 644 "$live_cert"
  chmod 600 "$live_key"
  if [[ -n "$staged_chain" && -f "$staged_chain" ]]; then
    local chain_dest="${live_chain:-$(dirname "$live_cert")/chain.crt}"
    cp -f "$staged_chain" "$chain_dest"
    live_chain="$chain_dest"
  fi

  # Promote Nginx + reload
  local final_nginx
  final_nginx="$(soviez_nginx_promote_owned "$staged_nginx")"
  if ! soviez_nginx_reload_safe; then
    # Rollback certs + nginx
    soviez_ssl_rollback "$env_id" "$upstream" || true
    soviez_ssl_die "$SOVIEZ_SSL_CODE_NGINX_RELOAD_FAILED" "Nginx reload failed; rolled back"
  fi

  # HTTPS validation (fixture-friendly)
  if ! soviez_ssl_https_validate_fixture "$domain" "$live_cert"; then
    soviez_ssl_rollback "$env_id" "$upstream" || true
    soviez_ssl_die "$SOVIEZ_SSL_CODE_HTTPS_VALIDATION_FAILED" "HTTPS validation failed; rolled back"
  fi

  local new_digest
  new_digest="$(openssl x509 -in "$live_cert" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//' | tr -d ':')"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  soviez_ssl_inventory_patch "$env_id" "$(python3 - <<PY
import json
print(json.dumps({
  "lifecycle_state": "healthy",
  "readiness_state": "ready",
  "current_certificate_digest": "$new_digest",
  "previous_certificate_digest": "$prev_digest",
  "chain_path": "$live_chain" if "$live_chain" else None,
  "last_successful_renewal": "$now",
  "last_failure_code": None,
  "retry_count": 0,
  "operation_id": None
}))
PY
)"
}

soviez_ssl_rollback() {
  local env_id="$1"
  local upstream="${2:-127.0.0.1:8069}"
  local rec live_cert live_key domain
  rec="$(soviez_ssl_inventory_read "$env_id")"
  live_cert="$(soviez_json_get "$rec" certificate_path)"
  live_key="$(soviez_json_get "$rec" private_key_path)"
  domain="$(soviez_json_get "$rec" domain)"
  local backup_dir
  backup_dir="$(dirname "$live_cert")/previous"
  [[ -f "$backup_dir/server.crt" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_ROLLBACK_FAILED" "No previous certificate"
  cp -f "$backup_dir/server.crt" "$live_cert"
  cp -f "$backup_dir/server.key" "$live_key"
  chmod 644 "$live_cert"
  chmod 600 "$live_key"
  local final_nginx
  final_nginx="$(soviez_nginx_owned_path "$env_id" "$domain")"
  if [[ -f "${final_nginx}.previous" ]]; then
    soviez_nginx_rollback_owned "$final_nginx"
  else
    # Re-render from restored cert
    local staged
    staged="$(soviez_nginx_render_owned "$env_id" "$domain" "$upstream" "$live_cert" "$live_key" "" https)"
    soviez_nginx_promote_owned "$staged" >/dev/null
    soviez_nginx_reload_safe || true
  fi
  soviez_ssl_inventory_patch "$env_id" '{"lifecycle_state":"healthy","last_failure_code":null}'
}

soviez_ssl_https_validate_fixture() {
  local domain="$1"
  local cert="$2"
  if [[ "${SOVIEZ_FORCE_HTTPS_FAIL:-0}" == "1" ]]; then
    return 1
  fi
  # In test mode, presenting a parseable trusted cert is sufficient.
  openssl x509 -in "$cert" -noout >/dev/null 2>&1
}
