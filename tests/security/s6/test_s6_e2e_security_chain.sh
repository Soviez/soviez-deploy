#!/usr/bin/env bash
# S6 — E2E security chain: quarantine hostile/clean + S3 scan + S5 network (owners).
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
  echo "==> E2E $t"
  if bash "$t"; then echo "OK $t"; else echo "FAIL $t" >&2; fail=1; fi
}

run "$ROOT/tests/security/quarantine/test_hostile_clean_scan.sh"
run "$ROOT/tests/security/quarantine/test_state_promotion.sh"
run "$ROOT/tests/security/quarantine/test_network_egress_cron.sh"
run "$ROOT/tests/security/detection/test_db_classifier_fixtures.sh"
run "$ROOT/tests/security/detection/test_yara_process.sh"
run "$ROOT/tests/security/detection/test_host_persistence_fixtures.sh"
run "$ROOT/tests/security/update_safety/test_s5_baseline_and_matrix.sh"
run "$ROOT/tests/security/backup_safety/test_s5_backup_integrity_posture.sh"
run "$ROOT/tests/security/backup_safety/test_s5_offhost_fixture.sh"
run "$ROOT/tests/security/test_phase23_offline_bundle_security.sh"

s6_write_json "$ev/findings/e2e_chain.json" "{\"status\":\"$([ $fail -eq 0 ] && echo PASS || echo FAIL)\",\"fail\":$fail}"
[[ $fail -eq 0 ]] || exit 1
echo PASS
