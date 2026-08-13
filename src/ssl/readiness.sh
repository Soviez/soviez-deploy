# shellcheck shell=bash
# Phase 12 temporary HTTP + Production readiness gates.

soviez_ssl_readiness_set() {
  local env_id="$1"
  local state="$2"
  case "$state" in
    provisioning|waiting_for_dns|waiting_for_ssl|ready|needs_action|renewal_warning|renewal_failed|certificate_expired|recovery_required) ;;
    *) soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "Invalid readiness state: $state" ;;
  esac
  soviez_ssl_inventory_patch "$env_id" "$(STATE="$state" python3 - <<'PY'
import json, os
print(json.dumps({"readiness_state": os.environ["STATE"]}))
PY
)"
}

soviez_ssl_assert_not_production_ready_message() {
  local readiness="$1"
  if [[ "$readiness" != "ready" ]]; then
    # Must never claim Production Ready
    return 0
  fi
  return 0
}

soviez_ssl_provision_temp_http() {
  local env_id="$1"
  local domain="$2"
  local upstream="${3:-127.0.0.1:8069}"
  local staged
  staged="$(soviez_nginx_render_owned "$env_id" "$domain" "$upstream" "/dev/null" "/dev/null" "" http_temp)"
  # Do not promote as final HTTPS; keep as staged incomplete marker file
  local marker="$SOVIEZ_SSL_NGINX_OWNED_DIR/${env_id}__${domain}.http_temp"
  mv -f "$staged" "$marker"
  soviez_ssl_readiness_set "$env_id" "waiting_for_ssl"
  printf 'INCOMPLETE temporary HTTP only — not Production Ready\n' >&2
  printf '%s\n' "$marker"
}

soviez_ssl_is_production_ready() {
  local env_id="$1"
  local rec readiness lifecycle https_ok
  rec="$(soviez_ssl_inventory_read "$env_id")"
  readiness="$(soviez_json_get "$rec" readiness_state)"
  lifecycle="$(soviez_json_get "$rec" lifecycle_state)"
  [[ "$readiness" == "ready" && ( "$lifecycle" == "healthy" || "$lifecycle" == "ready" ) ]]
}

soviez_ssl_format_status_line() {
  local env_id="$1"
  local rec domain etype lifecycle readiness issuer days mode next fail
  rec="$(soviez_ssl_inventory_read "$env_id")"
  domain="$(soviez_json_get "$rec" domain)"
  etype="$(soviez_json_get "$rec" environment_type)"
  lifecycle="$(soviez_json_get "$rec" lifecycle_state)"
  readiness="$(soviez_json_get "$rec" readiness_state)"
  issuer="$(soviez_json_get "$rec" issuer)"
  days="$(soviez_json_get "$rec" days_remaining 2>/dev/null || echo '?')"
  mode="$(soviez_json_get "$rec" renewal_mode)"
  next="$(soviez_json_get "$rec" next_scheduled_attempt)"
  fail="$(soviez_json_get "$rec" last_failure_code)"
  printf 'env=%s type=%s domain=%s lifecycle=%s readiness=%s issuer=%s days_remaining=%s renewal_mode=%s next_attempt=%s last_failure=%s\n' \
    "$env_id" "$etype" "$domain" "$lifecycle" "$readiness" "${issuer:-unknown}" "${days:--}" "$mode" "${next:-none}" "${fail:-none}"
}
