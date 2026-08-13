# shellcheck shell=bash
# Phase 12 renewal retry/backoff (owner-approved policy).

# Returns next delay seconds given retry_count (0-based after a failure).
# first 24h: every 6h → retries 0-3 at 6h
# days 2-7: once/day → 24h
# after day 7: every 3 days → 72h
soviez_ssl_backoff_seconds() {
  local retry_count="${1:-0}"
  if (( retry_count < 4 )); then
    printf '%s\n' "$((6 * 3600))"
  elif (( retry_count < 4 + 6 )); then
    printf '%s\n' "$((24 * 3600))"
  else
    printf '%s\n' "$((72 * 3600))"
  fi
}

soviez_ssl_backoff_next_iso() {
  local retry_count="${1:-0}"
  local delay now epoch
  delay="$(soviez_ssl_backoff_seconds "$retry_count")"
  now="$(date -u +%s)"
  epoch=$((now + delay))
  date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ
}

soviez_ssl_acquire_env_lock() {
  local env_id="$1"
  local lock
  soviez_ssl_paths_init
  mkdir -p "$(dirname "$(soviez_ssl_lock_dir "$env_id")")"
  lock="$(soviez_ssl_lock_dir "$env_id")"
  if ! mkdir "$lock" 2>/dev/null; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_RENEWAL_IN_PROGRESS" "Renewal already in progress for $env_id"
  fi
}

soviez_ssl_release_env_lock() {
  local env_id="$1"
  rmdir "$(soviez_ssl_lock_dir "$env_id")" 2>/dev/null || true
}
