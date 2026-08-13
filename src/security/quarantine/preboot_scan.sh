# shellcheck shell=bash
# Security Gate S4 — pre-boot raw SQL technical scan + S3 integration.

soviez_q_preboot_scan() {
  # Args: qid  — uses SOVIEZ_SEC_PG_* env like S3
  local qid="$1"
  local d out status
  d="$(soviez_q_dir "$qid")"
  mkdir -p "$d/scans"
  if ! declare -F soviez_s3_db_scan >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_PREBOOT_SCAN_FAILED: S3 scanner unavailable" >&2
    soviez_q_set_state "$qid" "SCAN_FAILED" >/dev/null
    return 1
  fi
  export SOVIEZ_S3_REQUIRE_ODOO_SCHEMA="${SOVIEZ_S3_REQUIRE_ODOO_SCHEMA:-1}"
  local ev
  if declare -F soviez_s3_evidence_init >/dev/null 2>&1; then
    export SOVIEZ_SEC_S3_EVIDENCE_ROOT="${SOVIEZ_SEC_S3_EVIDENCE_ROOT:-$d/evidence}"
    ev="$(soviez_s3_evidence_init "preboot-${qid}")"
  else
    ev="$d/evidence/preboot"
    mkdir -p "$ev/findings"
  fi
  out="$d/scans/preboot.json"
  local had_e=0
  [[ $- == *e* ]] && had_e=1
  set +e
  soviez_s3_db_scan "$ev" >"$out"
  local rc=$?
  [[ $had_e -eq 1 ]] && set -e
  status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","UNKNOWN"))' "$out" 2>/dev/null || echo UNKNOWN)"
  printf '%s\n' "$status" >"$d/scans/preboot.status"
  # Review pack (redacted findings)
  python3 - "$out" "$d/review/technical_records.json" <<'PY'
import json,sys
src,dst=sys.argv[1],sys.argv[2]
try:
  data=json.load(open(src))
except Exception:
  data={"findings":[],"status":"UNKNOWN"}
pack=[]
for f in data.get("findings") or []:
  pack.append({
    "model": f.get("model"),
    "record_id": f.get("record_id"),
    "xml_id": f.get("xml_id"),
    "name": f.get("name"),
    "active": f.get("active"),
    "rule_id": f.get("rule_id"),
    "severity": f.get("severity"),
    "snippet": f.get("snippet"),
    "content_fingerprint": f.get("content_fingerprint"),
    "module_hint": f.get("module_hint"),
  })
json.dump({"status": data.get("status"), "findings": pack, "full_bodies": False}, open(dst,"w"), indent=2)
PY
  # Update meta evidence id
  python3 - "$(soviez_q_dir "$qid")/meta.json" "$ev" "$status" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
m["evidence_run_id"]=sys.argv[2]
m["last_scan_status"]=sys.argv[3]
json.dump(m, open(sys.argv[1],"w"), indent=2)
PY
  case "$status" in
    PASS)
      soviez_q_set_state "$qid" "QUARANTINED" >/dev/null
      return 0
      ;;
    PASS_WITH_REVIEW)
      soviez_q_set_state "$qid" "REVIEW_REQUIRED" >/dev/null
      return 0
      ;;
    FAIL)
      soviez_q_set_state "$qid" "SCAN_FAILED" >/dev/null
      return 2
      ;;
    *)
      echo "[error] security:SEC_CRIT_PREBOOT_SCAN_FAILED: unknown status" >&2
      soviez_q_set_state "$qid" "SCAN_FAILED" >/dev/null
      return 1
      ;;
  esac
}

soviez_q_baseline_compare() {
  local qid="$1" index_json="${2:-}"
  local d
  d="$(soviez_q_dir "$qid")"
  if [[ -z "$index_json" || ! -f "$index_json" ]]; then
    echo '{"status":"NO_BASELINE"}' >"$d/scans/baseline_diff.json"
    echo NO_BASELINE
    return 0
  fi
  if declare -F soviez_s3_baseline_diff >/dev/null 2>&1; then
    soviez_s3_baseline_diff "$index_json" "environment" >"$d/scans/baseline_diff.json"
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","NO_BASELINE"))' "$d/scans/baseline_diff.json"
  else
    echo '{"status":"NO_BASELINE"}' >"$d/scans/baseline_diff.json"
    echo NO_BASELINE
  fi
}
