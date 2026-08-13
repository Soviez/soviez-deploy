#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAAS_ROOT="${SOVIEZ_SAAS_ROOT:-/Volumes/PortableSSD/soviez-project/soviez-saas}"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
fail=0
LOG="$EVID/matrix/SAAS_RUN.log"
: >"$LOG"
if [[ ! -d "$SAAS_ROOT" ]]; then
  echo "FAIL soviez-saas not found at $SAAS_ROOT" >&2
  exit 1
fi
run_saas() {
  local label="$1"
  shift
  echo "==> SaaS $label" | tee -a "$LOG"
  if (cd "$SAAS_ROOT" && "$@") >>"$LOG" 2>&1; then
    echo "OK $label" | tee -a "$LOG"
  else
    echo "FAIL $label" | tee -a "$LOG"
    fail=1
  fi
}
run_saas typecheck npm run typecheck
run_saas lint npm run lint
run_saas commercial-closure npm run test:commercial-closure
run_saas phase5-all npm run test:phase5-all
run_saas phase6-all npm run test:phase6-all
run_saas phase7-all npm run test:phase7-all
run_saas phase9-all npm run test:phase9-all
run_saas phase10-all npm run test:phase10-all
run_saas phase10.5-all npm run test:phase10.5-all
# Frozen UI contract only (no playwright browser)
run_saas phase11.5-contract node --require ./scripts/mock-server-only.cjs --import tsx --test \
  src/lib/create-operation-id.test.ts src/lib/preview/phase115.contract.test.ts
# soviez-sh SaaS integration proofs
if [[ "${SOVIEZ_P25_SKIP_NESTED:-0}" != "1" ]]; then
  bash "$ROOT/tests/integration/test_phase23_saas_typecheck_lint_build.sh" >>"$LOG" 2>&1 || fail=1
  bash "$ROOT/tests/integration/test_phase18_multi_tenant_isolation.sh" >>"$LOG" 2>&1 || fail=1
fi
{
  echo "# SAAS_BACKEND_CERTIFICATION"
  echo "result=$([[ $fail -eq 0 ]] && echo PASS || echo FAIL)"
  echo "ui_frozen=YES"
  echo "log=$LOG"
} >"$EVID/SAAS_BACKEND_CERTIFICATION.md"
cp "$EVID/SAAS_BACKEND_CERTIFICATION.md" "$EVID/MULTI_TENANT_CERTIFICATION.md"
[[ $fail -eq 0 ]] || exit 1
echo "OK saas_matrix"
exit 0
