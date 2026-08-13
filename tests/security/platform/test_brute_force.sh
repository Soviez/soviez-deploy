#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
d="$(soviez_bf_detect)"
[[ "$d" == "fail2ban" || "$d" == "crowdsec" || "$d" == "none" ]]
dec="$(soviez_bf_decision_record)"
echo "$dec" | grep -Eq 'KEEP_FAIL2BAN|CROWDSEC|NONE'
tmp="$(mktemp -d)"
export SOVIEZ_FAIL2BAN_JAIL="$tmp/soviez-s2.local"
# Write jail without installing (fail2ban may be absent)
mkdir -p "$tmp"
cat >"$SOVIEZ_FAIL2BAN_JAIL" <<'J'
# SOVIEZ_OWNED fail2ban — Security Gate S2
[sshd]
enabled = true
J
# Idempotent second write via ensure when fail2ban absent returns 0
soviez_bf_ensure_fail2ban_ssh
grep -q SOVIEZ_OWNED "$SOVIEZ_FAIL2BAN_JAIL"
# Ensure no odoo dataset jail
! grep -qi 'web/dataset' "$SOVIEZ_FAIL2BAN_JAIL"
echo PASS
rm -rf "$tmp"
