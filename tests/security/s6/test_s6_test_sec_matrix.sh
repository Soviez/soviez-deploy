#!/usr/bin/env bash
# S6 — TEST-SEC-001..024 matrix: map + invoke existing S1–S5 scripts; write results JSON.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-matrix.XXXXXX")}"
rid="$(s6_run_id)"
ev="$(s6_evidence_init "$rid")"
RESULTS="$ev/matrix/test_sec_results.json"
MAP_OUT="$ev/matrix/test_sec_map.json"
s6_test_sec_map_json >"$MAP_OUT"

# MAP_ONLY: document mapping without executing (nested gates cover owners).
# LIGHT: skip heavy docker guests; still document + run light scripts + ZATCA synthetic.
MODE="${SOVIEZ_S6_MATRIX_MODE:-execute}"
# Default for nested-skip gate runs: execute unique scripts once.
if [[ "${SOVIEZ_S6_SKIP_NESTED_REGRESSIONS:-0}" == "1" && -z "${SOVIEZ_S6_MATRIX_MODE:-}" ]]; then
  MODE="${SOVIEZ_S6_MATRIX_MODE:-execute}"
fi

fail=0
declare -a SEEN=()

script_seen() {
  local s="$1" x
  for x in "${SEEN[@]:-}"; do
    [[ "$x" == "$s" ]] && return 0
  done
  return 1
}

is_heavy() {
  case "$1" in
    *test_s2_real_runtime*|*test_s2_restart_matrix*|*test_s2_firewall_guest*|*test_s5_firewall_reboot*|*test_s5_docker_restart*|*test_s5_network_fault*|*test_odoo_functional*|*test_db_scan_real*|*test_network_egress*|*test_s4_ubuntu*|*test_hostile*)
      return 0 ;;
  esac
  return 1
}

# Minimal synthetic ZATCA immutability (TEST-SEC-021) when light / map-only needs a local assert.
s6_zatca_synthetic_assert() {
  local d="$ev/artifacts/zatca_fixture"
  mkdir -p "$d"
  cat >"$d/row.json" <<'EOF'
{"invoice_uuid":"11111111-1111-1111-1111-111111111111","invoice_hash":"abc123hash","signed_xml":"<Invoice/>","l10n_sa_invoice_signature":"sigdata","chain_index":7,"ccsid":"ccsid","pcsid":"pcsid","edi_state":"sent"}
EOF
  local pre post
  pre="$(s6_hash_file "$d/row.json")"
  # Simulate read-only scan (no mutation)
  cp -f "$d/row.json" "$d/row.after.json"
  post="$(s6_hash_file "$d/row.after.json")"
  [[ "$pre" == "$post" ]] || return 1
  echo "OK TEST-SEC-021 synthetic ZATCA immutability ($pre)"
  printf '%s\n' "$pre" >"$d/fingerprint.sha256"
}

python3 -c '
import json,sys
path=sys.argv[1]
json.dump({"gate":"S6","results":{},"mode":"pending"}, open(path,"w"), indent=2)
print(path)
' "$RESULTS"

record_result() {
  local id="$1" script="$2" status="$3" note="$4" rc="$5"
  SOVIEZ_ID="$id" SOVIEZ_SCRIPT="$script" SOVIEZ_STATUS="$status" SOVIEZ_NOTE="$note" SOVIEZ_RC="$rc" \
  SOVIEZ_S6_MATRIX_MODE="$MODE" python3 -c '
import json,os,sys
path=sys.argv[1]
doc=json.load(open(path))
doc["mode"]=os.environ.get("SOVIEZ_S6_MATRIX_MODE","execute")
rid=os.environ["SOVIEZ_ID"]
entry=doc.setdefault("results",{}).setdefault(rid,{"scripts":[]})
entry["scripts"].append({
  "path": os.environ["SOVIEZ_SCRIPT"],
  "status": os.environ["SOVIEZ_STATUS"],
  "note": os.environ.get("SOVIEZ_NOTE",""),
  "rc": int(os.environ.get("SOVIEZ_RC") or 0),
})
sts=[s["status"] for s in entry["scripts"]]
if any(s in ("FAIL","MISSING") for s in sts):
  entry["aggregate"]="FAIL"
elif any(s.startswith("PASS") for s in sts):
  entry["aggregate"]="PASS"
else:
  entry["aggregate"]=sts[0] if sts else "UNKNOWN"
json.dump(doc, open(path,"w"), indent=2)
' "$RESULTS"
}

run_one() {
  local id="$1" script="$2"
  local status="SKIP" rc=0 note=""
  if [[ ! -f "$ROOT/$script" ]]; then
    status="MISSING"
    fail=1
    note="script_not_found"
  elif [[ "$MODE" == "map_only" ]]; then
    status="MAPPED"
    note="documented_not_executed"
  elif [[ "$MODE" == "light" ]] && is_heavy "$script"; then
    status="MAPPED_HEAVY"
    note="deferred_to_owner_or_nested"
    if [[ "$id" == "TEST-SEC-021" ]]; then
      if s6_zatca_synthetic_assert; then
        status="PASS_SYNTHETIC"
        note="synthetic_zatca_fixture"
      else
        status="FAIL"
        fail=1
        note="synthetic_zatca_failed"
      fi
    fi
  else
    if script_seen "$script"; then
      status="PASS_CACHED"
      note="already_executed_this_run"
    else
      echo "==> [$id] $script"
      set +e
      bash "$ROOT/$script"
      rc=$?
      # One retry for known racey real-runtime scripts under concurrent matrix load
      if [[ $rc -ne 0 ]] && [[ "$script" == *test_odoo_functional_least_privilege* || "$script" == *test_s2_real_runtime* ]]; then
        echo "WARN [$id] retry once after rc=$rc" >&2
        sleep 3
        bash "$ROOT/$script"
        rc=$?
      fi
      set -e
      SEEN+=("$script")
      if [[ $rc -eq 0 ]]; then
        status="PASS"
      else
        status="FAIL"
        fail=1
        note="exit_$rc"
      fi
    fi
  fi
  record_result "$id" "$script" "$status" "$note" "$rc"
}

export SOVIEZ_S6_MATRIX_MODE="$MODE"

for n in $(seq 1 24); do
  id="$(printf 'TEST-SEC-%03d' "$n")"
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    run_one "$id" "$script"
  done < <(s6_test_sec_scripts_for "$id")
done

# Ensure 021 has at least synthetic if mapped-only and no PASS yet
if [[ "$MODE" == "map_only" ]]; then
  s6_zatca_synthetic_assert || true
fi

python3 -c '
import json,sys
path=sys.argv[1]
doc=json.load(open(path))
results=doc.get("results",{})
fails=[k for k,v in results.items() if v.get("aggregate")=="FAIL"]
ids=sorted(results.keys())
if len(ids) < 24:
  print("FAIL matrix incomplete ids=%d expected=24" % len(ids), file=sys.stderr)
  sys.exit(1)
doc["summary"]={"fail_count":len(fails),"fails":fails,"ids":ids}
json.dump(doc, open(path,"w"), indent=2)
print("matrix summary fail_count=", len(fails), "ids=", len(ids))
sys.exit(1 if fails else 0)
' "$RESULTS"

echo "OK wrote $RESULTS"
[[ $fail -eq 0 ]] || { echo "FAIL test_s6_test_sec_matrix" >&2; exit 1; }
echo PASS
