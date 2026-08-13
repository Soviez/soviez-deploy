#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
soviez_fw_assert_no_destructive_ops "$ROOT/src/security/platform/firewall.sh"
soviez_fw_assert_no_destructive_ops "$ROOT/src/security/platform/firewall_ufw.sh"
soviez_fw_assert_no_destructive_ops "$ROOT/src/security/platform/docker_firewall.sh"
# assembled dist
bash "$ROOT/build/assemble.sh" >/dev/null
soviez_fw_assert_no_destructive_ops "$ROOT/dist/soviez.sh"
echo PASS
