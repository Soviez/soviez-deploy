# shellcheck shell=bash
# Security Gate S4 — migration engine integration (P19 staging → quarantine → P20/P21).

soviez_q_migration_attach_staging() {
  local staging_id="$1"
  export SOVIEZ_Q_SOURCE_TYPE="${SOVIEZ_Q_SOURCE_TYPE:-migration}"
  export SOVIEZ_Q_DEST_ENV="migration_staging:${staging_id}"
  export SOVIEZ_Q_DEST_DB="${SOVIEZ_Q_DEST_DB:-}"
  local trust qid
  trust="$(soviez_q_classify_source)"
  export SOVIEZ_Q_TRUST="$trust"
  qid="$(soviez_q_create)"
  soviez_q_generate_fresh_secrets "$qid" >/dev/null
  soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
  # Persist linkage for cutover gate
  printf '%s\n' "$qid" >"$(soviez_q_dir "$qid")/migration_staging_id.txt"
  printf '%s\n' "$staging_id" >>"$(soviez_q_dir "$qid")/migration_staging_id.txt"
  export SOVIEZ_Q_ACTIVE_ID="$qid"
  printf '%s\n' "$qid"
}

soviez_q_migration_cutover_allowed() {
  # Fail-closed: unresolved quarantine blocks cutover; token must not be consumed by caller.
  local qid="${SOVIEZ_Q_ACTIVE_ID:-${1:-}}"
  if [[ -z "$qid" ]]; then
    if [[ "${SOVIEZ_Q_REQUIRE_FOR_CUTOVER:-1}" == "1" && "${SOVIEZ_MIG_SKIP_QUARANTINE:-0}" != "1" ]]; then
      # When migration quarantine feature is active for external sources
      if [[ "${SOVIEZ_Q_EXTERNAL_MIGRATION:-0}" == "1" ]]; then
        echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: cutover without quarantine id" >&2
        return 1
      fi
    fi
    return 0
  fi
  local state
  state="$(soviez_q_get_state "$qid")"
  if [[ "$state" != "PROMOTED" ]]; then
    echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: cutover blocked (quarantine state=$state)" >&2
    return 1
  fi
  return 0
}
