#!/usr/bin/env bash
# S5 corrective closure — apt lock safety runner.
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
bash -n src/security/update_safety/apt_lock.sh
command -v shellcheck >/dev/null 2>&1 && shellcheck -x src/security/update_safety/apt_lock.sh || true

run tests/security/update_safety/test_s5_corr_apt_lock.sh
run tests/security/update_safety/test_s5_corr_apt_lock_guest.sh
run tests/security/platform/test_legacy_installer_static.sh
run tests/security/update_safety/test_s5_package_policy.sh

if [[ "${SOVIEZ_CORR_SKIP_NESTED:-0}" != "1" ]]; then
  [[ -x tests/security/run_security_gate_s5.sh ]] && SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s5.sh
fi

if [[ $fail -ne 0 ]]; then
  echo "run_s5_corr_apt_lock: FAILED" >&2
  exit 1
fi
echo "run_s5_corr_apt_lock: PASS"
