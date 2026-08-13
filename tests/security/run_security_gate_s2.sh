#!/usr/bin/env bash
# Security Gate S2 authoritative suite runner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"

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

for t in \
  tests/security/platform/test_fw_backend_detect.sh \
  tests/security/platform/test_fw_no_destructive_ops.sh \
  tests/security/platform/test_fw_legacy_no_flush.sh \
  tests/security/platform/test_nginx_hardening.sh \
  tests/security/platform/test_trusted_proxy.sh \
  tests/security/platform/test_cloudflare_cache.sh \
  tests/security/platform/test_edge_modes.sh \
  tests/security/platform/test_ssh_staged.sh \
  tests/security/platform/test_ssh_lockout_safety.sh \
  tests/security/platform/test_brute_force.sh \
  tests/security/platform/test_webmin_detect.sh \
  tests/security/platform/test_host_baseline.sh \
  tests/security/platform/test_persistence_audit.sh \
  tests/security/platform/test_s2_rollback.sh \
  tests/security/platform/test_s2_idempotency.sh \
  tests/security/platform/test_s2_gate_fail_closed.sh \
  tests/security/platform/test_s2_real_runtime.sh \
  tests/security/platform/test_s2_restart_matrix.sh \
  tests/security/platform/test_s2_firewall_guest.sh \
  tests/security/platform/test_s2_ssh_guest.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

# S1 + Phase24 regressions (material) — skip when parent run_all already ran them
if [[ "${SOVIEZ_S2_SKIP_NESTED_REGRESSIONS:-0}" != "1" ]]; then
  if [[ -x tests/security/run_security_gate_s1.sh ]]; then
    run tests/security/run_security_gate_s1.sh
  fi
  if [[ -x tests/security/run_phase24_security.sh ]]; then
    run tests/security/run_phase24_security.sh
  fi
fi

if [[ $fail -ne 0 ]]; then
  echo "run_security_gate_s2: FAILED" >&2
  exit 1
fi
echo "run_security_gate_s2: PASS"
