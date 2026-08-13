#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
info="$(soviez_mgmt_detect_webmin)"
echo "$info" | grep -q present=
v="$(soviez_mgmt_detect_virtualmin)"
echo "$v" | grep -q present=
c="$(soviez_mgmt_classify_webmin)"
[[ "$c" == "N/A" || "$c" == "PASS" || "$c" == "WARNING" || "$c" == "FAIL" ]]
echo PASS
