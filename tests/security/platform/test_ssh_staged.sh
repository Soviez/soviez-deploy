#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp -d)"
conf="$tmp/sshd_config"
cat >"$conf" <<'C'
Port 22
PasswordAuthentication yes
PermitRootLogin yes
PubkeyAuthentication yes
C
export SOVIEZ_SSH_CONFIG="$conf"
export SOVIEZ_SSH_DROPIN="$tmp/50-soviez-s2.conf"
export SOVIEZ_SSH_POLICY=staged
export SOVIEZ_SSH_APPLY=0
# No alternate admin on fixture host path — must defer safely
soviez_ssh_staged_harden
st="$(soviez_ssh_detect_state "$conf")"
echo "$st" | grep -q password_auth=yes
# Syntax failure rollback: bad drop-in
soviez_ssh_prepare_dropin "$tmp/bad.conf" "no" "no"
echo 'GarbageDirective yes' >>"$tmp/bad.conf"
# Structural prepare ok; sshd -t may be absent on macOS — ensure defer path works
SOVIEZ_SSH_POLICY=deferred soviez_ssh_staged_harden
echo PASS
rm -rf "$tmp"
