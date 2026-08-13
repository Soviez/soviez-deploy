#!/usr/bin/env bash
# S6 — adversarial PG + Docker containment + archive safety (delegates to S1/S4 owners).
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
ev="$(s6_evidence_init "$(s6_run_id)")"

fail=0
run() {
  local t="$1"
  echo "==> ADV $t"
  if bash "$t"; then
    echo "OK $t"
  else
    echo "FAIL $t" >&2
    fail=1
  fi
}

run "$ROOT/tests/security/platform/test_pg_copy_program_denied.sh"
run "$ROOT/tests/security/platform/test_pg_server_files_denied.sh"
run "$ROOT/tests/security/platform/test_pg_least_privilege.sh"
run "$ROOT/tests/security/platform/test_docker_containment.sh"
run "$ROOT/tests/security/platform/test_odoo_port_isolation.sh"
run "$ROOT/tests/security/platform/test_pg_network_isolation.sh"
run "$ROOT/tests/security/quarantine/test_archive_safety.sh"
run "$ROOT/tests/security/platform/test_rollback_no_superuser_restore.sh"
run "$ROOT/tests/security/platform/test_webmin_detect.sh"
run "$ROOT/tests/security/update_safety/test_s5_corr_apt_lock.sh"

s6_write_json "$ev/findings/adversarial.json" "{\"status\":\"$([ $fail -eq 0 ] && echo PASS || echo FAIL)\",\"fail\":$fail}"
[[ $fail -eq 0 ]] || exit 1
echo PASS
