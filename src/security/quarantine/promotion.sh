# shellcheck shell=bash
# Security Gate S4 — explicit promotion / reject (never auto).

soviez_q_can_promote() {
  local qid="$1" target="${2:-APPROVED_FOR_STAGE}"
  local state scan approval
  state="$(soviez_q_get_state "$qid")"
  scan="$(cat "$(soviez_q_dir "$qid")/scans/preboot.status" 2>/dev/null || echo UNKNOWN)"
  approval="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("approval_status",""))' "$(soviez_q_dir "$qid")/meta.json" 2>/dev/null || echo PENDING)"

  case "$state" in
    SCAN_FAILED|REJECTED|UNTRUSTED_RESTORED)
      echo "[error] security:SEC_CRIT_PROMOTION_WITH_UNRESOLVED_CRITICAL: state=$state" >&2
      return 1
      ;;
  esac
  if [[ "$scan" == "FAIL" || "$scan" == "UNKNOWN" ]]; then
    echo "[error] security:SEC_CRIT_PROMOTION_WITH_UNRESOLVED_CRITICAL: scan=$scan" >&2
    return 1
  fi
  if [[ "$scan" == "PASS_WITH_REVIEW" && "$approval" != "REVIEW_ACCEPTED" && "$approval" != "APPROVED_FOR_STAGE" && "$approval" != "APPROVED_FOR_PRODUCTION" ]]; then
    echo "[error] security:SEC_HIGH_TECHNICAL_RECORD_REVIEW_REQUIRED: operator review required" >&2
    return 1
  fi
  # Critical UNKNOWN surfaces
  local d
  d="$(soviez_q_dir "$qid")"
  [[ -f "$d/network/egress_proof.txt" ]] || { echo "[error] security:SEC_CRIT_QUARANTINE_EGRESS_OPEN: egress unproven" >&2; return 1; }
  [[ -f "$d/secrets/infra.env" ]] || { echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: fresh secrets missing" >&2; return 1; }
  return 0
}

soviez_q_accept_review() {
  local qid="$1" approver="${2:-operator}" reason="${3:-reviewed}"
  local meta
  meta="$(soviez_q_dir "$qid")/meta.json"
  python3 - "$meta" "$approver" "$reason" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
m["approval_status"]="REVIEW_ACCEPTED"
m["approver"]=sys.argv[2]
m["reason"]=sys.argv[3]
json.dump(m, open(sys.argv[1],"w"), indent=2)
PY
  soviez_q_set_state "$qid" "VALIDATED" >/dev/null
}

soviez_q_promote() {
  local qid="$1" level="${2:-APPROVED_FOR_STAGE}" approver="${3:-operator}"
  soviez_q_acquire_lock "$qid" "promote" || return 1
  local rc=0
  if ! soviez_q_can_promote "$qid" "$level"; then
    soviez_q_release_lock "$qid"
    return 1
  fi
  local meta
  meta="$(soviez_q_dir "$qid")/meta.json"
  python3 - "$meta" "$level" "$approver" <<'PY'
import json,sys,datetime
m=json.load(open(sys.argv[1]))
m["approval_status"]=sys.argv[2]
m["approver"]=sys.argv[3]
m["promotion_utc"]=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump(m, open(sys.argv[1],"w"), indent=2)
PY
  soviez_q_set_state "$qid" "PROMOTED" >/dev/null
  # Record promotion enables (logical — actual runtime re-enable is operator/env)
  printf 'cron=enabled\nmail=enabled\negress=normal\npromoted=%s\n' "$level" \
    >"$(soviez_q_dir "$qid")/promotion.txt"
  echo "[security] SEC_OK_QUARANTINE_VALIDATED ($level)" >&2
  soviez_q_release_lock "$qid"
  return 0
}

soviez_q_reject() {
  local qid="$1" reason="${2:-rejected}"
  soviez_q_acquire_lock "$qid" "reject" || return 1
  python3 - "$(soviez_q_dir "$qid")/meta.json" "$reason" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
m["approval_status"]="REJECTED"
m["reason"]=sys.argv[2]
json.dump(m, open(sys.argv[1],"w"), indent=2)
PY
  soviez_q_set_state "$qid" "REJECTED" >/dev/null
  soviez_q_release_lock "$qid"
}
