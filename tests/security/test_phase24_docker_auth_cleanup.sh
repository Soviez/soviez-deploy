#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p24-docker.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Simulate interrupted pull cleanup expectation: leftover temp cfg fails assert
cfg="$TMP/leftover"
mkdir -p "$cfg"
set +e
(soviez_security_registry_assert_temp_config_clean "$cfg") >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
rm -rf "$cfg"

# release.sh must create operation-owned temp DOCKER_CONFIG for real pulls
grep -q 'soviez-dockercfg' src/update/release.sh
grep -q 'DOCKER_CONFIG' src/update/release.sh

# Certification require-clean flag
export SOVIEZ_PHASE24_REQUIRE_REGISTRY_CLEAN=1 SOVIEZ_PHASE24_CERTIFICATION=1
# Empty home docker config is fine
HOME="$TMP/home" mkdir -p "$TMP/home"
soviez_security_registry_assert_no_global_auth_for "registry.example.test"

echo "OK test_phase24_docker_auth_cleanup"
exit 0
