# shellcheck shell=bash

soviez_migration_dns_replay_seen() {
  local challenge_id="$1"
  local f="$SOVIEZ_MIG_DNS_REPLAY_DIR/${challenge_id}.seen"
  [[ -f "$f" ]]
}

soviez_migration_dns_replay_mark() {
  local challenge_id="$1"
  mkdir -p "$SOVIEZ_MIG_DNS_REPLAY_DIR"
  printf '%s\n' "$(soviez_migration_now_iso)" > "$SOVIEZ_MIG_DNS_REPLAY_DIR/${challenge_id}.seen"
}

soviez_migration_dns_replay_assert_fresh() {
  local challenge_id="$1"
  if soviez_migration_dns_replay_seen "$challenge_id"; then
    soviez_migration_die MIGRATION_DNS_CHALLENGE_REPLAY_DENIED "DNS challenge replay denied"
  fi
}
