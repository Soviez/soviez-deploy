#!/usr/bin/env bash
# Security Gate S3 authoritative suite runner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1

fail=0
run() {
  local t="$1"
  echo "==> $t"
  if bash "$t"; then
    echo "OK $t"
  else
    echo "FAIL $t" >&2
    fail=1
  fi
}

bash build/assemble.sh
bash -n dist/soviez.sh
command -v shellcheck >/dev/null 2>&1 && shellcheck -x src/security/detection/*.sh || true

for t in \
  tests/security/detection/test_db_classifier_fixtures.sh \
  tests/security/detection/test_db_scan_real_odoo_schema.sh \
  tests/security/detection/test_db_failclosed_missing_model.sh \
  tests/security/detection/test_baseline_safety.sh \
  tests/security/detection/test_host_persistence_fixtures.sh \
  tests/security/detection/test_yara_process.sh \
  tests/security/detection/test_addon_scan.sh \
  tests/security/detection/test_evidence_failclosed_retention.sh \
  tests/security/detection/test_s3_ubuntu_guest.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

if [[ "${SOVIEZ_S3_SKIP_NESTED_REGRESSIONS:-0}" != "1" ]]; then
  [[ -x tests/security/run_security_gate_s2.sh ]] && SOVIEZ_S2_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s2.sh
  [[ -x tests/security/run_security_gate_s1.sh ]] && run tests/security/run_security_gate_s1.sh
  [[ -x tests/security/run_phase24_security.sh ]] && run tests/security/run_phase24_security.sh
fi

if [[ $fail -ne 0 ]]; then
  echo "run_security_gate_s3: FAILED" >&2
  exit 1
fi
echo "run_security_gate_s3: PASS"
