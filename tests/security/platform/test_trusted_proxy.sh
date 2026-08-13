#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_EDGE_MODE=direct
# Direct always ok for remote_addr policy
soviez_edge_trust_client_ip "1.2.3.4"
export SOVIEZ_EDGE_MODE=cloudflare
# Known CF range from LKG
soviez_edge_trust_client_ip "104.16.1.1"
if soviez_edge_trust_client_ip "8.8.8.8"; then
  echo FAIL spoofed CF trust >&2; exit 1
fi
tmp="$(mktemp)"
cat >"$tmp" <<'N'
set_real_ip_from 0.0.0.0/0;
N
if soviez_edge_reject_spoofed_xff_policy "$tmp"; then
  echo FAIL should reject 0.0.0.0/0 >&2; exit 1
fi
rm -f "$tmp"
echo PASS
