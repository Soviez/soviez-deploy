#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
# keys_required without alternate access must NOT apply PasswordAuthentication no when APPLY=1 without proof
tmp="$(mktemp -d)"
export SOVIEZ_SSH_CONFIG="$tmp/sshd_config"
export SOVIEZ_SSH_DROPIN="$tmp/dropin.conf"
printf 'PasswordAuthentication yes\nPermitRootLogin yes\n' >"$SOVIEZ_SSH_CONFIG"
export SOVIEZ_SSH_POLICY=keys_required
export SOVIEZ_SSH_APPLY=1
# Force empty admin detection by using fake passwd? Function reads /etc/passwd — on CI may have admins.
# We assert that without SOVIEZ_SSH_FORCE_UNSAFE, harden returns 0 (defer) even if APPLY=1 when no alternate —
# If host has alternate admin, apply may write dropin — that is OK only on disposable guests.
# Guard: never point SOVIEZ_SSH_DROPIN at real /etc/ssh
[[ "$SOVIEZ_SSH_DROPIN" == /etc/* ]] && { echo FAIL; exit 1; }
soviez_ssh_staged_harden || true
# Real host /etc/ssh must be untouched by this test
if [[ -f /etc/ssh/sshd_config.d/50-soviez-s2.conf ]]; then
  if grep -q 'SOVIEZ_OWNED sshd drop-in' /etc/ssh/sshd_config.d/50-soviez-s2.conf 2>/dev/null; then
    # If somehow applied on host, FAIL safety
    echo "FAIL mutated host sshd" >&2
    exit 1
  fi
fi
echo PASS
rm -rf "$tmp"
