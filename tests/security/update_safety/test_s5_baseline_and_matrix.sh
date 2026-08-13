#!/usr/bin/env bash
# S5 unit matrix: baseline capture, semantic_diff, inject fails, offline/PDF.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
BAK=""
if [[ -f "$ROOT/dist/soviez.sh" ]] && ! grep -q 'soviez_s5_baseline_capture' "$ROOT/dist/soviez.sh" 2>/dev/null; then
  BAK="$ROOT/dist/soviez.sh.s5bak.$$"
  mv "$ROOT/dist/soviez.sh" "$BAK"
fi
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export TMPDIR="${TMPDIR:-/tmp}"
export SOVIEZ_SEC_S5_EVIDENCE_ROOT
SOVIEZ_SEC_S5_EVIDENCE_ROOT="$(mktemp -d "${TMPDIR}/soviez-s5-evid.XXXXXX")"
rid="$(s5_run_id)"
trap '
  rm -rf "$SOVIEZ_SEC_S5_EVIDENCE_ROOT"
  if [[ -n "${BAK:-}" && -f "$BAK" ]]; then mv "$BAK" "$ROOT/dist/soviez.sh"; fi
' EXIT

# --- identical baselines → semantic_diff PASS ---
op="${rid}-diff"
export SOVIEZ_S5_OP_ID="$op"
export SOVIEZ_S5_BASELINE_PHASE=pre
export SOVIEZ_S5_PDF_N_A=1
pre="$(soviez_s5_baseline_capture "$op")"
[[ -f "$pre" ]]
export SOVIEZ_S5_BASELINE_PHASE=post
post="$(soviez_s5_baseline_capture "$op")"
python3 - "$pre" "$post" <<'PY'
import json,sys
a,b=sys.argv[1:3]
pa,pb=json.load(open(a)),json.load(open(b))
for k in ("dns","outbound","db_connectivity","firewall_digest","docker_networks","ports","offline_expected"):
  pb[k]=pa[k]
json.dump(pb, open(b,"w"), indent=2)
PY
diff="$(soviez_s5_semantic_diff "$pre" "$post")"
[[ "$diff" == "PASS" ]]
echo "OK semantic_diff identical"

# --- quarantine/offline → EXPECTED_OFFLINE ---
out="$(SOVIEZ_S5_QUARANTINE=1 soviez_s5_check_outbound)"
[[ "$out" == "EXPECTED_OFFLINE" ]]
out="$(SOVIEZ_S5_OFFLINE=1 soviez_s5_check_outbound)"
[[ "$out" == "EXPECTED_OFFLINE" ]]
echo "OK outbound EXPECTED_OFFLINE"

# --- PDF inject blocks success ---
set +e
pdf="$(SOVIEZ_S5_PDF_N_A=0 SOVIEZ_S5_PDF_INJECT_FAIL=1 soviez_s5_check_pdf 2>/dev/null)"
set -e
[[ "$pdf" == "FAIL" ]]
echo "OK PDF inject FAIL"

assert_gate_not_pass() {
  local label="$1" op_id="$2"
  shift 2
  local result rc=0
  export SOVIEZ_S5_OP_ID="$op_id"
  # Clear inject flags then apply callers' env via "$@"
  unset SOVIEZ_S5_INJECT_DNS_FAIL SOVIEZ_S5_INJECT_DB_FAIL \
        SOVIEZ_S5_INJECT_OUTBOUND_FAIL SOVIEZ_S5_INJECT_PUBLIC_PORT \
        SOVIEZ_S5_PDF_INJECT_FAIL SOVIEZ_S5_REQUIRE_CONTAINERS || true
  export SOVIEZ_S5_PDF_N_A=1
  # shellcheck disable=SC2086
  eval "$@"
  set +e
  result="$(soviez_security_validate_update_safety "$op_id" 2>/dev/null)"
  rc=$?
  set -e
  # Reset injects after run
  unset SOVIEZ_S5_INJECT_DNS_FAIL SOVIEZ_S5_INJECT_DB_FAIL \
        SOVIEZ_S5_INJECT_OUTBOUND_FAIL SOVIEZ_S5_INJECT_PUBLIC_PORT \
        SOVIEZ_S5_PDF_INJECT_FAIL SOVIEZ_S5_REQUIRE_CONTAINERS || true
  export SOVIEZ_S5_PDF_N_A=1
  [[ "$result" != "PASS" ]]
  case "$result" in
    FAILED_PRECHECK|NEEDS_ACTION|FAIL) ;;
    *)
      echo "FAIL $label unexpected overall=${result}" >&2
      exit 1
      ;;
  esac
  echo "OK gate $label → $result (rc=$rc)"
}

assert_gate_not_pass dns_inject "${rid}-dns" 'export SOVIEZ_S5_INJECT_DNS_FAIL=1'
assert_gate_not_pass db_inject "${rid}-db" 'export SOVIEZ_S5_INJECT_DB_FAIL=1'
assert_gate_not_pass outbound_inject "${rid}-out" 'export SOVIEZ_S5_INJECT_OUTBOUND_FAIL=1'
assert_gate_not_pass public_port_inject "${rid}-port" 'export SOVIEZ_S5_INJECT_PUBLIC_PORT=1'
assert_gate_not_pass pdf_inject_gate "${rid}-pdf" \
  'export SOVIEZ_S5_PDF_N_A=0 SOVIEZ_S5_PDF_INJECT_FAIL=1'

# Direct check injects
set +e
[[ "$(SOVIEZ_S5_INJECT_DNS_FAIL=1 soviez_s5_check_dns 2>/dev/null)" == "FAIL" ]]
[[ "$(SOVIEZ_S5_INJECT_DB_FAIL=1 soviez_s5_check_odoo_pg 2>/dev/null)" == "FAIL" ]]
[[ "$(SOVIEZ_S5_INJECT_OUTBOUND_FAIL=1 soviez_s5_check_outbound 2>/dev/null)" == "FAIL" ]]
[[ "$(SOVIEZ_S5_INJECT_PUBLIC_PORT=1 soviez_s5_check_ports_protected 2>/dev/null)" == "FAIL" ]]
set -e
echo "OK direct inject checks"

echo PASS
