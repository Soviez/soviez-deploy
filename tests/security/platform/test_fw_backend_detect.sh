#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
b="$(soviez_fw_detect_backend)"
[[ -n "$b" ]]
echo "PASS backend=$b"
