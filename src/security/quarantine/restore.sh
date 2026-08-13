# shellcheck shell=bash
# Security Gate S4 — restore workflow integration hook.

soviez_q_restore_enter() {
  # Called after untrusted restore candidate materializes — before Production switch.
  local trust source_id dest_db
  trust="$(soviez_q_classify_source)"
  export SOVIEZ_Q_TRUST="$trust"
  export SOVIEZ_Q_SOURCE_ID="${SOVIEZ_Q_SOURCE_ID:-$source_id}"
  export SOVIEZ_Q_DEST_DB="${SOVIEZ_Q_DEST_DB:-$dest_db}"
  local qid
  qid="$(soviez_q_create)"
  soviez_q_generate_fresh_secrets "$qid" >/dev/null
  if soviez_q_requires_full_quarantine "$trust"; then
    soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
  else
    # Trusted path still records quarantine id for integrity trail
    soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
  fi
  printf '%s\n' "$qid"
}

soviez_q_restore_block_switch_if_needed() {
  # Gate Production switch: require PROMOTED for untrusted sources.
  local qid="${1:-}"
  [[ -n "$qid" ]] || qid="${SOVIEZ_Q_ACTIVE_ID:-}"
  if [[ -z "$qid" ]]; then
    # No quarantine id — if force external restore, block
    if [[ "${SOVIEZ_Q_EXTERNAL_RESTORE:-0}" == "1" ]]; then
      echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: external restore without quarantine" >&2
      return 1
    fi
    return 0
  fi
  local state trust
  state="$(soviez_q_get_state "$qid")"
  trust="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("source_trust",""))' "$(soviez_q_dir "$qid")/meta.json")"
  if soviez_q_requires_full_quarantine "$trust" || [[ "${SOVIEZ_Q_FORCE_QUARANTINE:-0}" == "1" ]]; then
    if [[ "$state" != "PROMOTED" ]]; then
      echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: restore switch blocked (state=$state)" >&2
      return 1
    fi
  fi
  return 0
}
