# shellcheck shell=bash
# Security Gate S3 — technical baseline fingerprints (security layer only).

soviez_s3_baseline_dir() {
  local d="${SOVIEZ_S3_BASELINE_DIR:-}"
  if [[ -z "$d" ]]; then
    d="${SOVIEZ_ROOT:-.}/security/baselines"
    [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] && d="${TMPDIR:-/tmp}/soviez-s3-baselines-$$"
  fi
  mkdir -p "$d"
  chmod 700 "$d" 2>/dev/null || true
  printf '%s\n' "$d"
}

soviez_s3_baseline_save() {
  # Save fingerprints from records_index.json (no full bodies).
  local index_json="$1"
  local name="${2:-environment}"
  local dir reason
  dir="$(soviez_s3_baseline_dir)"
  reason="${SOVIEZ_S3_BASELINE_REASON:-}"
  if [[ -z "$reason" && "${SOVIEZ_S3_BASELINE_FORCE:-0}" != "1" ]]; then
    echo "[error] security:SEC_WARN_TECHNICAL_RECORD_DRIFT: baseline save requires SOVIEZ_S3_BASELINE_REASON" >&2
    return 1
  fi
  # Refuse save when CRITICAL findings unresolved
  if [[ -n "${SOVIEZ_S3_UNRESOLVED_CRITICAL:-}" && "${SOVIEZ_S3_UNRESOLVED_CRITICAL}" != "0" ]]; then
    echo "[error] security:SEC_CRIT_DB_KNOWN_MALWARE_IOC: refuse rebaseline with unresolved CRITICAL findings" >&2
    return 1
  fi
  local dest="${dir}/${name}.baseline.json"
  if [[ -f "$dest" ]]; then
    cp -a "$dest" "${dest}.previous.$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
  fi
  python3 - "$index_json" "$dest" "$reason" <<'PY'
import json,sys,hashlib,datetime
idx=json.load(open(sys.argv[1]))
obj={
  "baseline_version":"s3-1",
  "saved_utc":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "reason":sys.argv[3],
  "records":idx.get("records") or [],
}
raw=json.dumps(obj["records"], sort_keys=True)
obj["baseline_sha256"]=hashlib.sha256(raw.encode()).hexdigest()
json.dump(obj, open(sys.argv[2],"w"), indent=2)
print(sys.argv[2])
PY
  chmod 600 "$dest" 2>/dev/null || true
}

soviez_s3_baseline_diff() {
  local index_json="$1"
  local name="${2:-environment}"
  local dir base
  dir="$(soviez_s3_baseline_dir)"
  base="${dir}/${name}.baseline.json"
  if [[ ! -f "$base" ]]; then
    printf '{"status":"NO_BASELINE","added":[],"removed":[],"changed":[]}\n'
    return 0
  fi
  python3 - "$base" "$index_json" <<'PY'
import json,sys
base=json.load(open(sys.argv[1]))
cur=json.load(open(sys.argv[2]))
b={(r.get("model"),r.get("id"),r.get("field")):r for r in base.get("records") or []}
c={(r.get("model"),r.get("id"),r.get("field")):r for r in cur.get("records") or []}
added=[c[k] for k in c.keys()-b.keys()]
removed=[b[k] for k in b.keys()-c.keys()]
changed=[]
for k in c.keys()&b.keys():
  if (b[k].get("content_sha256")!=c[k].get("content_sha256")) or (b[k].get("active")!=c[k].get("active")):
    changed.append({"before":b[k],"after":c[k]})
status="PASS"
if added or removed or changed:
  status="PASS_WITH_REVIEW"
print(json.dumps({"status":status,"added":added,"removed":removed,"changed":changed}, indent=2))
PY
}
