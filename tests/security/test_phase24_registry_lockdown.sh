#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p24-reg.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Temp config cleanup assertion
cfg="$TMP/dockercfg"
mkdir -p "$cfg"
printf '{"auths":{"registry.example":{"auth":"dGVzdA=="}}}\n' > "$cfg/config.json"
set +e
(soviez_security_registry_assert_temp_config_clean "$cfg") >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
rm -rf "$cfg"
(soviez_security_registry_assert_temp_config_clean "") >/dev/null 2>&1

# Fixture token denied on production
export SOVIEZ_SECURITY_FORCE_PRODUCTION=1 SOVIEZ_PHASE24_FORBID_TEST_BYPASS=1 SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="/var/lib/soviez-production-not-disposable" SOVIEZ_DISPOSABLE_ENV=0
set +e
# Direct policy check
soviez_security_test_bypass_allowed
rc=$?
set -e
[[ $rc -ne 0 ]]

# Source must use ephemeral DOCKER_CONFIG pattern in registry export
grep -q 'DOCKER_CONFIG' src/offline_bundle/export/registry.sh
grep -q 'rm -rf' src/offline_bundle/export/registry.sh

echo "OK test_phase24_registry_lockdown"
exit 0
