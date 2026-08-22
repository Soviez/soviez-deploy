#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

soviez_security_scan_dist "$ROOT/dist/soviez.sh"
soviez_security_assert_no_service_role_in_file "$ROOT/dist/soviez.sh"

# No private keys / PEM (line-anchored)
if grep -E '^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----' dist/soviez.sh >/dev/null 2>&1; then
  echo "FAIL private key in dist" >&2
  exit 1
fi

# No Phase 25 implementation markers
if grep -E 'PHASE25_IMPLEMENTATION|phase25_engine|PHASE_25_AUTHORIZED=1' dist/soviez.sh >/dev/null 2>&1; then
  echo "FAIL Phase 25 code in dist" >&2
  exit 1
fi

ver="$(grep -m1 '^# version:' dist/soviez.sh | awk '{print $3}')"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/dist_version.sh"
if ! soviez_test_accept_dist_version "$ver"; then
  echo "FAIL version=$ver" >&2
  exit 1
fi

echo "DIST SECURITY SCAN — PASS"
echo "OK test_phase24_dist_scan"
exit 0
