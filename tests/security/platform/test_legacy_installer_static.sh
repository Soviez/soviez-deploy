#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s1_platform_source
ERP="/Volumes/PortableSSD/soviez-project/Soviez ERP/soviez.sh"
LEG="/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh"
soviez_sec_legacy_assert_installer_safe "$ERP"
soviez_sec_legacy_assert_installer_safe "$LEG"
soviez_sec_legacy_assert_apt_lock_safe "$ERP"
soviez_sec_legacy_assert_apt_lock_safe "$LEG"
# Public deploy bootstrap is not the ERP dual wizard; both must remain statically safe.
! grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+apt' "$LEG"
! grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+apt' "$ERP"
echo "PASS legacy installer static (ERP wizard + deploy bootstrap, distinct)"
