#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
fail=0
run() {
  local id="$1" t="$2"
  echo "==> E2E $id $t"
  if bash "$ROOT/$t"; then
    echo "OK $id"
    echo "$id=PASS path=$t" >>"$EVID/matrix/E2E_CERTIFICATION_MATRIX.md"
  else
    echo "FAIL $id $t" >&2
    echo "$id=FAIL path=$t" >>"$EVID/matrix/E2E_CERTIFICATION_MATRIX.md"
    fail=1
  fi
}
mkdir -p "$EVID/matrix"
{
  echo "# E2E_CERTIFICATION_MATRIX"
  echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
} >"$EVID/matrix/E2E_CERTIFICATION_MATRIX.md"

if [[ "${SOVIEZ_P25_SKIP_NESTED:-0}" == "1" ]]; then
  # Lightweight path inside run_all: representative material proofs only
  run P25-E2E-01 tests/security/s6/test_s6_e2e_security_chain.sh
  run P25-E2E-06 tests/security/s6/test_s6_full_restore_depth.sh
  run P25-E2E-11 tests/security/s6/test_s6_adversarial_matrix.sh
else
  run P25-E2E-01 tests/security/s6/test_s6_e2e_security_chain.sh
  run P25-E2E-02 tests/integration/test_phase23_real_airgapped_apply.sh
  run P25-E2E-03 tests/integration/test_update_final_certification.sh
  run P25-E2E-04 tests/integration/test_phase23_offline_bundle_integration.sh
  run P25-E2E-05 tests/integration/test_phase18_domain_dns_landing_tls_e2e.sh
  run P25-E2E-06 tests/security/s6/test_s6_full_restore_depth.sh
  run P25-E2E-07 tests/security/quarantine/test_state_promotion.sh
  run P25-E2E-08 tests/integration/test_phase21_cutover_e2e.sh
  run P25-E2E-09 tests/integration/test_phase22_runtime_suspend_response_loss.sh
  run P25-E2E-10 tests/integration/test_phase22_license_finalization_response_loss.sh
  run P25-E2E-11 tests/security/s6/test_s6_adversarial_matrix.sh
  run P25-E2E-12 tests/integration/test_phase16_reboot_matrix.sh
fi
cp "$EVID/matrix/E2E_CERTIFICATION_MATRIX.md" "$EVID/E2E_CERTIFICATION_MATRIX.md"
[[ $fail -eq 0 ]] || exit 1
echo "OK e2e_matrix"
exit 0
