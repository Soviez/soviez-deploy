#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

# Inventory dangerous flags in security modules (policy present)
grep -q 'soviez_security_test_bypass_allowed' src/security/test_flag_policy.sh

# Single env var insufficient
unset SOVIEZ_TEST_MODE SOVIEZ_DISPOSABLE_ENV SOVIEZ_SECURITY_FORCE_PRODUCTION SOVIEZ_PHASE24_FORBID_TEST_BYPASS
export SOVIEZ_ROOT="/opt/soviez/production"
export SOVIEZ_MIG_ALLOW_UNSIGNED_OFFLINE_TEST=1
export SOVIEZ_UPDATE_STRICT_SIG=0
export SOVIEZ_TEST_MODE=0
set +e
soviez_security_test_bypass_allowed
rc=$?
set -e
[[ $rc -ne 0 ]]

# TEST_MODE alone insufficient without disposable
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="/opt/soviez/production" SOVIEZ_DISPOSABLE_ENV=0
unset SOVIEZ_PHASE24_CERTIFICATION SOVIEZ_PHASE23_CERTIFICATION
set +e
soviez_security_test_bypass_allowed
rc=$?
set -e
[[ $rc -ne 0 ]]

# Triple: TEST_MODE + disposable + not production => allowed
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="/tmp/soviez-p24-test" SOVIEZ_DISPOSABLE_ENV=1
export SOVIEZ_SECURITY_FORCE_PRODUCTION=0 SOVIEZ_PHASE24_FORBID_TEST_BYPASS=0
soviez_security_test_bypass_allowed

# FORBID_TEST_BYPASS denies even disposable
export SOVIEZ_PHASE24_FORBID_TEST_BYPASS=1
set +e
soviez_security_test_bypass_allowed
rc=$?
set -e
[[ $rc -ne 0 ]]

# Migration unsigned flag alone insufficient (code path check)
grep -q 'soviez_security_test_bypass_allowed' src/migration/pairing/offline.sh

echo "OK test_phase24_test_flag_quarantine"
exit 0
