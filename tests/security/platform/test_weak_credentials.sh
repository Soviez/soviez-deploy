#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s1_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
echo "TEST-SEC-014 weak credentials"
soviez_sec_password_is_weak admin
soviez_sec_password_is_weak odoo
soviez_sec_password_is_weak password
soviez_sec_password_is_weak admin123
soviez_sec_password_is_weak 12345678
soviez_sec_password_is_weak qwerty
soviez_sec_password_is_weak changeme
soviez_sec_password_is_weak root
# Strong password must not be classified weak
if soviez_sec_password_is_weak "SafeStrongPass9xQy"; then
  echo "FAIL strong classified weak"; exit 1
fi
# Prefer is_weak over assert_not_weak (assert may call soviez_security_die / exit)
set +e
soviez_sec_password_assert_not_weak "SafeStrongPass9xQyZZ" "ok"
rc=$?
set -e
[[ $rc -eq 0 ]] || { echo "FAIL assert strong"; exit 1; }
echo "PASS TEST-SEC-014"
