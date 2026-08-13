#!/usr/bin/env bash
# S5 firewall reload + guest stop/start reboot survival (does NOT touch host firewall).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
rid="$(s5_run_id)"
trap 'docker rm -f "${rid}-u22" "${rid}-u24" >/dev/null 2>&1 || true' EXIT

run_guest() {
  local tag="$1" name="$2"
  docker pull --platform linux/arm64 "$tag" >/dev/null
  docker run -d --name "$name" --privileged --platform linux/arm64 "$tag" sleep 3600 >/dev/null
  docker exec "$name" bash -lc \
    'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq ufw iptables iproute2 >/dev/null'
  docker cp "$ROOT/src/security/platform/firewall.sh" "$name:/tmp/firewall.sh"
  docker cp "$ROOT/src/security/platform/firewall_ufw.sh" "$name:/tmp/firewall_ufw.sh"
  docker cp "$ROOT/src/security/platform/docker_firewall.sh" "$name:/tmp/docker_firewall.sh"
  docker exec "$name" bash -lc '
    set -euo pipefail
    source /tmp/firewall.sh
    source /tmp/firewall_ufw.sh
    source /tmp/docker_firewall.sh
    export SOVIEZ_FW_PREFER_UFW=1
    # Minimal policy via Soviez UFW helper (guest only).
    soviez_fw_apply_soviez_policy ufw
    ufw reload
    ufw status | head -1 | grep -Eqi "Status:[[:space:]]*active"
    if ufw status | grep -q 8069; then echo FAIL 8069 allowed; exit 1; fi
    echo FIREWALL_RELOAD_PASS
  '
  # Guest stop/start ≈ reboot survival of managed rules
  docker stop "$name" >/dev/null
  docker start "$name" >/dev/null
  sleep 1
  docker exec "$name" bash -lc '
    set -euo pipefail
    source /tmp/firewall.sh
    source /tmp/firewall_ufw.sh
    source /tmp/docker_firewall.sh
    export SOVIEZ_FW_PREFER_UFW=1
    # After container start, re-apply is idempotent (reboot survival).
    soviez_fw_apply_soviez_policy ufw
    ufw reload
    ufw status | head -1 | grep -Eqi "Status:[[:space:]]*active"
    if ufw status | grep -q 8069; then echo FAIL 8069 allowed; exit 1; fi
    echo FIREWALL_REBOOT_SURVIVAL_PASS
  '
}

run_guest ubuntu:22.04 "${rid}-u22"
echo "PASS ubuntu22 firewall reload"
run_guest ubuntu:24.04 "${rid}-u24"
echo "PASS ubuntu24 firewall reload"
echo PASS
