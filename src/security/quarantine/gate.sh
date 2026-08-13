# shellcheck shell=bash
# Security Gate S4 — authoritative quarantine gate + CLI commands.

soviez_security_validate_quarantine() {
  local qid="${1:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  [[ -n "$qid" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: quarantine id required" >&2; return 1; }
  local d
  d="$(soviez_q_dir "$qid")"
  [[ -f "$d/meta.json" ]] || return 1
  soviez_q_report_write "$qid" >/dev/null
  local overall
  overall="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("overall",""))' "$d/report.json")"
  case "$overall" in
    PASS) echo "[security] SEC_OK_QUARANTINE_VALIDATED" >&2; return 0 ;;
    REVIEW_REQUIRED) echo "[security] SEC_WARN_REVIEW_REQUIRED" >&2; return 0 ;;
    *) echo "[security] quarantine FAIL ($overall)" >&2; return 1 ;;
  esac
}

soviez_cmd_security_quarantine_create() {
  export SOVIEZ_TEST_MODE="${SOVIEZ_TEST_MODE:-0}"
  local trust
  trust="$(soviez_q_classify_source)"
  export SOVIEZ_Q_TRUST="$trust"
  local qid
  qid="$(soviez_q_create "${SOVIEZ_CLI_Q_ID:-}")"
  soviez_q_generate_fresh_secrets "$qid" >/dev/null
  soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
  export SOVIEZ_Q_ACTIVE_ID="$qid"
  echo "quarantine_id=$qid"
  echo "trust=$trust"
  echo "state=$(soviez_q_get_state "$qid")"
}

soviez_cmd_security_quarantine_status() {
  local qid="${SOVIEZ_CLI_Q_ID:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  [[ -n "$qid" ]] || { echo "quarantine id required" >&2; return 1; }
  cat "$(soviez_q_dir "$qid")/meta.json"
  echo
  soviez_q_report_write "$qid" >/dev/null || true
  cat "$(soviez_q_dir "$qid")/report.txt" 2>/dev/null || true
}

soviez_cmd_security_quarantine_scan() {
  local qid="${SOVIEZ_CLI_Q_ID:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  [[ -n "$qid" ]] || { echo "quarantine id required" >&2; return 1; }
  soviez_q_preboot_scan "$qid"
  local st=$?
  soviez_q_report_write "$qid" >/dev/null || true
  return "$st"
}

soviez_cmd_security_quarantine_promote() {
  local qid="${SOVIEZ_CLI_Q_ID:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  local level="${SOVIEZ_CLI_Q_APPROVAL:-APPROVED_FOR_STAGE}"
  [[ -n "$qid" ]] || { echo "quarantine id required" >&2; return 1; }
  soviez_q_promote "$qid" "$level" "${SOVIEZ_CLI_Q_APPROVER:-operator}"
}

soviez_cmd_security_quarantine_reject() {
  local qid="${SOVIEZ_CLI_Q_ID:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  [[ -n "$qid" ]] || { echo "quarantine id required" >&2; return 1; }
  soviez_q_reject "$qid" "${SOVIEZ_CLI_Q_REASON:-rejected}"
}

soviez_cmd_security_quarantine_accept_review() {
  local qid="${SOVIEZ_CLI_Q_ID:-${SOVIEZ_Q_ACTIVE_ID:-}}"
  [[ -n "$qid" ]] || { echo "quarantine id required" >&2; return 1; }
  soviez_q_accept_review "$qid" "${SOVIEZ_CLI_Q_APPROVER:-operator}" "${SOVIEZ_CLI_Q_REASON:-reviewed}"
}
