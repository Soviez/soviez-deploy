#!/usr/bin/env bash
# Disposable Ubuntu guest SSH staged harden — never touch workstation sshd.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
rid="$(s2_run_id)"
name="${rid}-ssh"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" --privileged ubuntu:24.04 sleep 3600 >/dev/null
docker exec "$name" bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq openssh-server sudo >/dev/null; mkdir -p /run/sshd; ssh-keygen -A >/dev/null 2>&1 || true'
docker cp "$ROOT/src/security/platform/ssh.sh" "$name:/tmp/ssh.sh"
docker exec "$name" bash -lc '
  set -euo pipefail
  source /tmp/ssh.sh
  useradd -m -s /bin/bash soviezadmin
  usermod -aG sudo soviezadmin
  mkdir -p /home/soviezadmin/.ssh
  ssh-keygen -t ed25519 -N "" -f /tmp/k >/dev/null
  cat /tmp/k.pub > /home/soviezadmin/.ssh/authorized_keys
  chown -R soviezadmin:soviezadmin /home/soviezadmin/.ssh
  chmod 700 /home/soviezadmin/.ssh
  chmod 600 /home/soviezadmin/.ssh/authorized_keys
  # Defer path without APPLY
  export SOVIEZ_SSH_POLICY=staged SOVIEZ_SSH_APPLY=0
  soviez_ssh_has_alternate_access
  soviez_ssh_staged_harden
  # Apply drop-in under /tmp only
  export SOVIEZ_SSH_DROPIN=/tmp/50-soviez-s2.conf SOVIEZ_SSH_APPLY=1 SOVIEZ_SSH_CONFIG=/etc/ssh/sshd_config
  soviez_ssh_staged_harden
  grep -q "PasswordAuthentication no" /tmp/50-soviez-s2.conf
  # Defer without alternate: remove keys
  rm -f /home/soviezadmin/.ssh/authorized_keys
  export SOVIEZ_SSH_POLICY=keys_required SOVIEZ_SSH_APPLY=1 SOVIEZ_SSH_DROPIN=/tmp/50-b.conf
  soviez_ssh_staged_harden
  # Should not create hardened drop-in forcing lockout without keys
  if [[ -f /tmp/50-b.conf ]] && grep -q "PasswordAuthentication no" /tmp/50-b.conf; then
    # If created despite no keys — only OK if has_alternate still true somehow
    if ! soviez_ssh_has_alternate_access; then
      echo FAIL applied without alternate >&2; exit 1
    fi
  fi
'
echo PASS
