# shellcheck shell=bash

soviez_migration_now_epoch() {
  date -u +%s
}

soviez_migration_now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

soviez_migration_iso_to_epoch() {
  local iso="$1"
  if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null; then
    return 0
  fi
  date -u -d "$iso" +%s 2>/dev/null || python3 -c "import datetime,sys; s=sys.argv[1].replace('Z','+00:00'); print(int(datetime.datetime.fromisoformat(s).timestamp()))" "$iso"
}

soviez_migration_expires_iso() {
  local ttl="${1:-86400}"
  python3 -c "import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$ttl"
}

soviez_migration_is_expired() {
  local expires_iso="$1"
  local now exp
  now="$(soviez_migration_now_epoch)"
  exp="$(soviez_migration_iso_to_epoch "$expires_iso")" || return 0
  [[ "$now" -ge "$exp" ]]
}

soviez_migration_clock_skew_seconds() {
  local remote_epoch="${1:-}"
  local now
  now="$(soviez_migration_now_epoch)"
  if [[ -z "$remote_epoch" ]]; then
    printf '0\n'
    return 0
  fi
  python3 -c "print(abs(int('$now')-int('$remote_epoch')))"
}

soviez_migration_assert_clock_skew() {
  local remote_epoch="${1:-}"
  local skew maxs
  skew="$(soviez_migration_clock_skew_seconds "$remote_epoch")"
  maxs="${SOVIEZ_MIG_CLOCK_SKEW_MAX_SECONDS:-300}"
  if [[ "$skew" -gt "$maxs" ]]; then
    soviez_migration_die MIGRATION_CLOCK_SKEW_BLOCKED "Clock skew ${skew}s exceeds ${maxs}s"
  fi
}
