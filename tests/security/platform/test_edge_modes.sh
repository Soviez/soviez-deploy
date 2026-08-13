#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
SOVIEZ_EDGE_MODE=direct soviez_edge_validate_mode
SOVIEZ_EDGE_MODE=cloudflare soviez_edge_validate_mode
if SOVIEZ_EDGE_MODE=cloudflare_aop SOVIEZ_EDGE_AOP_ENABLED=0 soviez_edge_validate_mode 2>/dev/null; then
  echo FAIL aop should be unsupported without CA >&2; exit 1
fi
[[ "$(soviez_edge_aop_status)" == "N/A" || "$(SOVIEZ_EDGE_MODE=cloudflare_aop soviez_edge_aop_status)" == "UNSUPPORTED" ]]
echo PASS
