#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp)"
export SOVIEZ_EDGE_MODE=direct
soviez_nginx_s2_render_hardened "example.test" "127.0.0.1:18069" "/c.pem" "/k.pem" "$tmp" https
soviez_nginx_s2_validate_syntax "$tmp"
grep -q 'server_tokens off' "$tmp"
grep -q 'return 301 https' "$tmp"
grep -q 'X-Content-Type-Options' "$tmp"
grep -q 'limit_req zone=soviez_login' "$tmp"
grep -q '/websocket' "$tmp"
soviez_edge_reject_spoofed_xff_policy "$tmp"
# reject public upstream
if soviez_nginx_s2_render_hardened "x" "8.8.8.8:80" "/c" "/k" "${tmp}.bad" https 2>/dev/null; then
  echo FAIL expected upstream reject >&2; exit 1
fi
rm -f "$tmp" "${tmp}.bad"
echo PASS
