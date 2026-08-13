#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp -d)"
export SOVIEZ_FAIL2BAN_JAIL="$tmp/jail.local"
export SOVIEZ_SSH_DROPIN="$tmp/sshd.dropin"
export SOVIEZ_SSH_CONFIG="$tmp/sshd_config"
printf 'PasswordAuthentication yes\n' >"$SOVIEZ_SSH_CONFIG"
export SOVIEZ_SSH_POLICY=deferred
export SOVIEZ_FW_APPLY=0
soviez_bf_ensure_fail2ban_ssh
soviez_bf_ensure_fail2ban_ssh
# single SOVIEZ_OWNED marker count
c="$(grep -c SOVIEZ_OWNED "$SOVIEZ_FAIL2BAN_JAIL" || true)"
[[ "$c" -eq 1 ]]
out1="$(mktemp)"; out2="$(mktemp)"
soviez_nginx_s2_render_hardened d 127.0.0.1:1 /c /k "$out1" https
soviez_nginx_s2_render_hardened d 127.0.0.1:1 /c /k "$out2" https
cmp -s "$out1" "$out2"
echo PASS
rm -rf "$tmp" "$out1" "$out2"
