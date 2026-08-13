#!/usr/bin/env bash
# Real UFW in privileged disposable Ubuntu guest — does not touch host firewall.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
rid="$(s2_run_id)"
trap 'docker rm -f "${rid}-u22" "${rid}-u24" >/dev/null 2>&1 || true' EXIT

run_guest() {
  local tag="$1" name="$2"
  docker pull --platform linux/arm64 "$tag" >/dev/null
  docker run -d --name "$name" --privileged --platform linux/arm64 "$tag" sleep 3600 >/dev/null
  docker exec "$name" bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq ufw iptables iproute2 >/dev/null'
  docker cp "$ROOT/src/security/platform/firewall.sh" "$name:/tmp/firewall.sh"
  docker cp "$ROOT/src/security/platform/firewall_ufw.sh" "$name:/tmp/firewall_ufw.sh"
  docker cp "$ROOT/src/security/platform/docker_firewall.sh" "$name:/tmp/docker_firewall.sh"
  docker exec "$name" bash -lc '
    set -euo pipefail
    source /tmp/firewall.sh
    source /tmp/firewall_ufw.sh
    source /tmp/docker_firewall.sh
    export SOVIEZ_FW_PREFER_UFW=1
    b=$(soviez_fw_detect_backend)
    echo backend=$b
    [[ "$b" == "ufw" ]]
    snap=$(soviez_fw_snapshot /tmp/fwsnap)
    soviez_fw_apply_soviez_policy ufw
    soviez_fw_validate ufw
    ufw status verbose | tee /tmp/ufw.after
    grep -E "80/tcp|443/tcp|22/tcp|OpenSSH" /tmp/ufw.after >/dev/null
    if grep -q 8069 /tmp/ufw.after; then echo FAIL 8069 allowed; exit 1; fi
    ufw reload || true
    ufw status | head -1 | grep -Eqi 'Status:[[:space:]]*active'
    # Docker-user chain best-effort
    soviez_fw_docker_apply_user_chain || true
    soviez_fw_rollback /tmp/fwsnap || true
    echo GUEST_OK
  '
}

run_guest ubuntu:22.04 "${rid}-u22"
echo "PASS ubuntu22"
run_guest ubuntu:24.04 "${rid}-u24"
echo "PASS ubuntu24"
echo PASS
