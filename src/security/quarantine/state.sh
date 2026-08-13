# shellcheck shell=bash
# Security Gate S4 — quarantine lifecycle state (local-only).

soviez_q_root() {
  local base="${SOVIEZ_SEC_QUARANTINE_ROOT:-}"
  if [[ -z "$base" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      base="${TMPDIR:-/tmp}/soviez-s4-quarantine"
    else
      base="${SOVIEZ_ROOT:-/var/lib/soviez}/security/quarantine"
    fi
  fi
  mkdir -p "$base"
  chmod 700 "$base" 2>/dev/null || true
  printf '%s\n' "$base"
}

soviez_q_dir() {
  printf '%s/%s\n' "$(soviez_q_root)" "$1"
}

soviez_q_lock_path() {
  printf '%s/%s.lock\n' "$(soviez_q_root)" "$1"
}

soviez_q_acquire_lock() {
  local qid="$1" purpose="${2:-op}"
  local lp
  lp="$(soviez_q_lock_path "$qid")"
  if [[ -f "$lp" ]]; then
    echo "[error] security:SEC_CRIT_QUARANTINE_BYPASSED: concurrent operation lock held ($purpose)" >&2
    return 1
  fi
  printf '%s %s %s\n' "$$" "$purpose" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$lp"
  chmod 600 "$lp" 2>/dev/null || true
}

soviez_q_release_lock() {
  rm -f "$(soviez_q_lock_path "$1")"
}

soviez_q_new_id() {
  printf 'q-%s-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$" "${RANDOM}"
}

soviez_q_get_state() {
  local qid="$1"
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("state",""))' \
    "$(soviez_q_dir "$qid")/meta.json" 2>/dev/null || echo UNKNOWN
}

soviez_q_set_state() {
  local qid="$1" state="$2"
  local meta
  meta="$(soviez_q_dir "$qid")/meta.json"
  [[ -f "$meta" ]] || return 1
  python3 - "$meta" "$state" <<'PY'
import json,sys,datetime
p,st=sys.argv[1],sys.argv[2]
m=json.load(open(p))
hist=m.setdefault("state_history",[])
hist.append({"from":m.get("state"),"to":st,"utc":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")})
m["state"]=st
json.dump(m, open(p,"w"), indent=2)
print(st)
PY
}

soviez_q_create() {
  local qid="${1:-}"
  [[ -n "$qid" ]] || qid="$(soviez_q_new_id)"
  local d trust src_type ver rules
  d="$(soviez_q_dir "$qid")"
  if [[ -f "$d/meta.json" ]]; then
    printf '%s\n' "$qid"
    return 0
  fi
  trust="${SOVIEZ_Q_TRUST:-EXTERNAL_UNKNOWN}"
  src_type="${SOVIEZ_Q_SOURCE_TYPE:-external}"
  mkdir -p "$d"/{evidence,scans,network,secrets,locks,review,filestore,extract}
  chmod 700 "$d"
  ver="$(cat "${SOVIEZ_SH_ROOT:-.}/VERSION" 2>/dev/null || echo unknown)"
  rules="$(cat "${SOVIEZ_SH_ROOT:-.}/share/security/detection/schema_version" 2>/dev/null || echo unknown)"
  SOVIEZ_Q_ID="$qid" SOVIEZ_Q_TRUST_V="$trust" SOVIEZ_Q_SRC_T="$src_type" \
  SOVIEZ_Q_VER="$ver" SOVIEZ_Q_RULES="$rules" \
  SOVIEZ_Q_SRC_ID="${SOVIEZ_Q_SOURCE_ID:-}" SOVIEZ_Q_DEST_E="${SOVIEZ_Q_DEST_ENV:-destination}" \
  SOVIEZ_Q_DEST_D="${SOVIEZ_Q_DEST_DB:-}" SOVIEZ_Q_RSN="${SOVIEZ_Q_REASON:-}" \
  python3 <<'PY' >"$d/meta.json"
import json,os,datetime
trust=os.environ["SOVIEZ_Q_TRUST_V"]
obj={
  "quarantine_id": os.environ["SOVIEZ_Q_ID"],
  "immutable_original_id": os.environ["SOVIEZ_Q_ID"],
  "state": "UNTRUSTED_RESTORED",
  "source_type": os.environ["SOVIEZ_Q_SRC_T"],
  "source_identity": os.environ.get("SOVIEZ_Q_SRC_ID",""),
  "source_trust": trust,
  "destination_environment": os.environ.get("SOVIEZ_Q_DEST_E","destination"),
  "destination_db": os.environ.get("SOVIEZ_Q_DEST_D",""),
  "restore_utc": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "quarantine_start_utc": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "scanner_version": os.environ.get("SOVIEZ_Q_VER",""),
  "ruleset_version": os.environ.get("SOVIEZ_Q_RULES",""),
  "evidence_run_id": "",
  "approval_status": "PENDING",
  "approver": "",
  "reason": os.environ.get("SOVIEZ_Q_RSN",""),
  "promotion_utc": "",
  "local_only": True,
  "telemetry": False,
  "destructive_remediation": False,
  "incident_preserve": trust in ("INCIDENT_SUSPECTED","COMPROMISED_CONFIRMED"),
  "state_history": [{"from":None,"to":"UNTRUSTED_RESTORED","utc":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")}],
}
print(json.dumps(obj, indent=2))
PY
  chmod 600 "$d/meta.json"
  case "$trust" in
    INCIDENT_SUSPECTED|COMPROMISED_CONFIRMED)
      touch "$d/PRESERVE" "$d/INCIDENT"
      ;;
  esac
  printf '%s\n' "$qid"
}