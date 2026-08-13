#!/usr/bin/env bash
# Security Gate S4 authoritative suite runner.
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
command -v shellcheck >/dev/null 2>&1 && shellcheck -x src/security/quarantine/*.sh || true

for t in \
  tests/security/quarantine/test_archive_safety.sh \
  tests/security/quarantine/test_state_promotion.sh \
  tests/security/quarantine/test_network_egress_cron.sh \
  tests/security/quarantine/test_hostile_clean_scan.sh \
  tests/security/quarantine/test_s4_ubuntu_guest.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

if [[ "${SOVIEZ_S4_SKIP_NESTED_REGRESSIONS:-0}" != "1" ]]; then
  [[ -x tests/security/run_security_gate_s3.sh ]] && SOVIEZ_S3_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s3.sh
  [[ -x tests/security/run_security_gate_s2.sh ]] && SOVIEZ_S2_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s2.sh
  [[ -x tests/security/run_security_gate_s1.sh ]] && run tests/security/run_security_gate_s1.sh
  [[ -x tests/security/run_phase24_security.sh ]] && run tests/security/run_phase24_security.sh
fi

if [[ $fail -ne 0 ]]; then
  echo "run_security_gate_s4: FAILED" >&2
  exit 1
fi
echo "run_security_gate_s4: PASS"
