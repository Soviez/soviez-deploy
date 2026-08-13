#!/usr/bin/env bash
# Security Gate S1 authoritative suite runner.
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
  tests/security/platform/test_weak_credentials.sh \
  tests/security/platform/test_stage_credentials.sh \
  tests/security/platform/test_odoo_prod_defaults.sh \
  tests/security/platform/test_legacy_installer_static.sh \
  tests/security/platform/test_rollback_no_superuser_restore.sh \
  tests/security/platform/test_pg_least_privilege.sh \
  tests/security/platform/test_pg_copy_program_denied.sh \
  tests/security/platform/test_pg_server_files_denied.sh \
  tests/security/platform/test_pg_network_isolation.sh \
  tests/security/platform/test_odoo_port_isolation.sh \
  tests/security/platform/test_docker_containment.sh \
  tests/security/platform/test_security_gate_fail_closed.sh \
  tests/security/platform/test_s1_idempotency.sh \
  tests/security/platform/test_bootstrap_secret_not_in_odoo_env.sh \
  tests/security/platform/test_s1_real_runtime.sh \
  tests/security/platform/test_odoo_functional_least_privilege.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

if [[ $fail -ne 0 ]]; then
  echo "run_security_gate_s1: FAILED" >&2
  exit 1
fi
echo "run_security_gate_s1: PASS"
