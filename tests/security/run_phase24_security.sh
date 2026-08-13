#!/usr/bin/env bash
# Phase 24 consolidated security suite runner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

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

bash build/assemble.sh >/dev/null
bash -n dist/soviez.sh

for t in \
  tests/security/test_phase24_signature_enforcement.sh \
  tests/security/test_phase24_self_update_signature.sh \
  tests/security/test_phase24_signer_purpose.sh \
  tests/security/test_phase24_key_hygiene.sh \
  tests/security/test_phase24_ticket_replay.sh \
  tests/security/test_phase24_registry_lockdown.sh \
  tests/security/test_phase24_docker_auth_cleanup.sh \
  tests/security/test_phase24_test_flag_quarantine.sh \
  tests/security/test_phase24_secret_scan.sh \
  tests/security/test_phase24_dist_scan.sh \
  tests/security/test_phase24_cross_tenant.sh \
  tests/security/test_phase24_sovereignty_regression.sh \
  tests/security/test_phase24_phase25_readiness.sh \
  tests/security/test_phase24_no_duplicate_engines.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

# Authoritative secret scan gate
if ! bash tools/secret_scan.sh all; then
  echo "FAIL tools/secret_scan.sh" >&2
  fail=1
else
  echo "OK tools/secret_scan.sh"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "run_phase24_security: FAILED" >&2
  exit 1
fi
echo "run_phase24_security: PASS"
exit 0
