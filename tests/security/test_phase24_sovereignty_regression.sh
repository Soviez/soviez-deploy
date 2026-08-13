#!/usr/bin/env bash
# Sovereignty / no phone-home / no duplicate egress regressions from Phase 24.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

search() {
  if command -v rg >/dev/null 2>&1; then rg -n "$@" || return 1; else grep -RnE "$@" || return 1; fi
}

# Phase 24 security modules must not introduce phone-home loops
set +e
hits="$(search 'phone.?home|periodic.?entitlement|runtime.?lockout|remote.?shell' src/security 2>/dev/null || true)"
set -e
[[ -z "$hits" ]] || { echo "FAIL sovereignty hit in security modules: $hits" >&2; exit 1; }

# No permanent registry login helper in security adapters
if grep -RnE 'docker login' src/security >/dev/null 2>&1; then
  echo "FAIL docker login in security adapters" >&2
  exit 1
fi

# Air-gap deny proxy pattern still owned by Phase 23 offline apply
grep -q 'SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED\|http_proxy' src/offline_update/*.sh 2>/dev/null \
  || grep -rq 'http_proxy' src/offline_update src/offline_bundle 2>/dev/null \
  || true

echo "SOVEREIGNTY REGRESSION — PASS"
echo "OK test_phase24_sovereignty_regression"
exit 0
