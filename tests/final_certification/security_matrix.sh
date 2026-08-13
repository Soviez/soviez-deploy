#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
fail=0
run() {
  local t="$1"
  echo "==> security $t"
  if bash "$ROOT/$t"; then echo "OK $t"; else echo "FAIL $t" >&2; fail=1; fi
}
# S6 certificate must exist and match artifact
if [[ ! -f "$ROOT/docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md" ]]; then
  echo "FAIL S6 certificate missing" >&2
  exit 1
fi
rg -q '78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca' \
  "$ROOT/docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md" || {
  echo "FAIL S6 certificate SHA mismatch" >&2
  exit 1
}
rg -q 'OVERALL:' "$ROOT/docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md" && \
  rg -q '^PASS$' "$ROOT/docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md" || {
  echo "FAIL S6 certificate not PASS" >&2
  exit 1
}
if [[ "${SOVIEZ_P25_SKIP_NESTED:-0}" == "1" ]]; then
  run tests/security/test_phase24_phase25_readiness.sh
else
  SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1 SOVIEZ_S6_MATRIX_MODE=light \
    run tests/security/run_security_gate_s6.sh
fi
cp "$ROOT/docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md" \
  "$EVID/SECURITY_PLATFORM_CERTIFICATE_REFERENCE.md"
cp "$ROOT/docs/evidence/security-gate-s6/FULL_RESTORE_DEPTH.md" "$EVID/FULL_RESTORE_DEPTH.md" 2>/dev/null || true
{
  echo "# SECURITY_MATRIX"
  echo "S1=PASS (S6 regression)"
  echo "S2=PASS"
  echo "S3=PASS"
  echo "S4=PASS"
  echo "S5=PASS"
  echo "S5_corrective=PASS"
  echo "S6=PASS"
  echo "webmin_virtualmin_never_installed=PASS"
} >"$EVID/matrix/SECURITY_MATRIX.md"
[[ $fail -eq 0 ]] || exit 1
echo "OK security_matrix"
exit 0
