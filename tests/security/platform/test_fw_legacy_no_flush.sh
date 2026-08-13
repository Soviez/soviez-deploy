#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
ERP="$(cd "$ROOT/.." && pwd)/Soviez ERP/soviez.sh"
DEP="$(cd "$ROOT/.." && pwd)/soviez-deploy/soviez.sh"
soviez_sec_legacy_assert_s2_firewall_safe "$ERP"
soviez_sec_legacy_assert_s2_firewall_safe "$DEP"
echo PASS
