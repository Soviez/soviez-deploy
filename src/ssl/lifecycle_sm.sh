# shellcheck shell=bash
# Phase 12 certificate lifecycle state machine (durable, resumable).

SOVIEZ_SSL_STATES=(
  healthy
  renewal_window
  renewal_scheduled
  renewal_authorizing
  challenge_preparing
  waiting_for_dns
  challenge_validating
  certificate_issuing
  certificate_received
  certificate_validating
  nginx_staging
  nginx_validating
  nginx_reloading
  https_validating
  certificate_promoting
  completed
  retry_scheduled
  needs_action
  certificate_expired
  rollback_running
  recovery_required
  canceled
  failed_retryable
  failed_terminal
  provisioning
  waiting_for_ssl
  ready
)

soviez_ssl_sm_is_known() {
  local s="$1"
  local x
  for x in "${SOVIEZ_SSL_STATES[@]}"; do
    [[ "$x" == "$s" ]] && return 0
  done
  return 1
}

soviez_ssl_sm_can_transition() {
  local from="$1"
  local to="$2"
  [[ "$from" == "$to" ]] && return 0
  case "$from:$to" in
    healthy:renewal_window|healthy:needs_action|healthy:certificate_expired) return 0 ;;
    renewal_window:renewal_scheduled|renewal_window:needs_action) return 0 ;;
    renewal_scheduled:renewal_authorizing|renewal_scheduled:canceled|renewal_scheduled:needs_action) return 0 ;;
    renewal_authorizing:challenge_preparing|renewal_authorizing:failed_retryable|renewal_authorizing:needs_action) return 0 ;;
    challenge_preparing:waiting_for_dns|challenge_preparing:failed_retryable) return 0 ;;
    waiting_for_dns:challenge_validating|waiting_for_dns:retry_scheduled|waiting_for_dns:canceled|waiting_for_dns:needs_action) return 0 ;;
    challenge_validating:certificate_issuing|challenge_validating:failed_retryable|challenge_validating:needs_action) return 0 ;;
    certificate_issuing:certificate_received|certificate_issuing:failed_retryable|certificate_issuing:acme*) return 0 ;;
    certificate_issuing:retry_scheduled|certificate_issuing:needs_action) return 0 ;;
    certificate_received:certificate_validating|certificate_received:rollback_running) return 0 ;;
    certificate_validating:nginx_staging|certificate_validating:rollback_running|certificate_validating:failed_retryable) return 0 ;;
    nginx_staging:nginx_validating|nginx_staging:rollback_running) return 0 ;;
    nginx_validating:nginx_reloading|nginx_validating:rollback_running) return 0 ;;
    nginx_reloading:https_validating|nginx_reloading:rollback_running) return 0 ;;
    https_validating:certificate_promoting|https_validating:rollback_running) return 0 ;;
    certificate_promoting:completed|certificate_promoting:rollback_running) return 0 ;;
    completed:healthy) return 0 ;;
    failed_retryable:retry_scheduled|failed_retryable:needs_action|failed_retryable:recovery_required) return 0 ;;
    retry_scheduled:renewal_authorizing|retry_scheduled:canceled|retry_scheduled:needs_action) return 0 ;;
    needs_action:renewal_authorizing|needs_action:rollback_running|needs_action:recovery_required|needs_action:canceled) return 0 ;;
    certificate_expired:renewal_authorizing|certificate_expired:needs_action|certificate_expired:recovery_required) return 0 ;;
    rollback_running:healthy|rollback_running:needs_action|rollback_running:recovery_required|rollback_running:failed_terminal) return 0 ;;
    recovery_required:renewal_authorizing|recovery_required:canceled) return 0 ;;
    provisioning:waiting_for_dns|provisioning:waiting_for_ssl|provisioning:needs_action) return 0 ;;
    waiting_for_dns:waiting_for_ssl|waiting_for_dns:needs_action) return 0 ;;
    waiting_for_ssl:ready|waiting_for_ssl:needs_action) return 0 ;;
    ready:healthy|ready:renewal_window) return 0 ;;
    canceled:healthy|failed_terminal:recovery_required) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_ssl_sm_assert_transition() {
  local from="$1"
  local to="$2"
  soviez_ssl_sm_is_known "$from" || soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "Unknown SSL state: $from"
  soviez_ssl_sm_is_known "$to" || soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "Unknown SSL state: $to"
  if ! soviez_ssl_sm_can_transition "$from" "$to"; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "Illegal SSL transition $from -> $to"
  fi
}

# Current working certificate is preserved in all states except successful promotion.
soviez_ssl_sm_preserves_current_cert() {
  local state="$1"
  case "$state" in
    certificate_promoting|completed) return 1 ;;
    *) return 0 ;;
  esac
}
