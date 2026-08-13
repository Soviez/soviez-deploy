# shellcheck shell=bash
# Security Gate S4 — rollback from failed promotion → quarantine.

soviez_q_rollback_to_quarantine() {
  local qid="$1" reason="${2:-post_promotion_validation_failed}"
  soviez_q_acquire_lock "$qid" "rollback" || return 1
  # Re-disable ordinary egress/cron/mail markers
  printf 'cron=disabled\nmail=disabled\negress=DENIED\nrollback_reason=%s\n' "$reason" \
    >"$(soviez_q_dir "$qid")/network/policy.txt"
  rm -f "$(soviez_q_dir "$qid")/promotion.txt"
  python3 - "$(soviez_q_dir "$qid")/meta.json" "$reason" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
m["approval_status"]="REVIEW_REQUIRED"
m["reason"]=sys.argv[2]
m["promotion_utc"]=""
json.dump(m, open(sys.argv[1],"w"), indent=2)
PY
  soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
  soviez_q_release_lock "$qid"
  echo "[security] rolled back to quarantine ($qid)" >&2
}
