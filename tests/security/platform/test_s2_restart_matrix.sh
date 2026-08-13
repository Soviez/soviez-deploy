#!/usr/bin/env bash
# TEST-SEC-012/013/024 — restart resilience matrix (firewall reload + Docker restart).
# Full host reboot uses disposable guest when practical; Colima host reboot is out of scope.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
rid="$(s2_run_id)"
trap 's2_cleanup_containers "$rid"; docker rm -f "${rid}-fw" >/dev/null 2>&1 || true' EXIT

docker network create "${rid}-net" >/dev/null
docker run -d --name "${rid}-pg" --network "${rid}-net" --network-alias db \
  -e POSTGRES_PASSWORD=s2 -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
docker run -d --name "${rid}-web" --network "${rid}-net" \
  -p 127.0.0.1:28169:8069 hashicorp/http-echo:1.0 -listen=:8069 -text=ok >/dev/null
docker run -d --name "${rid}-probe" --network "${rid}-net" busybox:1.36 sleep 3600 >/dev/null
sleep 2
docker exec "${rid}-probe" nslookup db >/dev/null 2>&1 || docker exec "${rid}-probe" ping -c1 -W2 db >/dev/null

# Docker restart
docker restart "${rid}-web" "${rid}-pg" >/dev/null
sleep 3
docker exec "${rid}-probe" nslookup db >/dev/null 2>&1 || docker exec "${rid}-probe" ping -c1 -W2 db >/dev/null
docker port "${rid}-web" 8069 | grep -q 127.0.0.1

# Firewall reload in privileged Ubuntu guest (not host)
docker pull --platform linux/arm64 ubuntu:24.04 >/dev/null
docker run -d --name "${rid}-fw" --privileged --platform linux/arm64 ubuntu:24.04 sleep 3600 >/dev/null
docker exec "${rid}-fw" bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq ufw iptables >/dev/null'
docker cp "$ROOT/src/security/platform/firewall.sh" "${rid}-fw:/tmp/firewall.sh"
docker cp "$ROOT/src/security/platform/firewall_ufw.sh" "${rid}-fw:/tmp/firewall_ufw.sh"
docker cp "$ROOT/src/security/platform/docker_firewall.sh" "${rid}-fw:/tmp/docker_firewall.sh"
docker exec "${rid}-fw" bash -lc '
  set -euo pipefail
  source /tmp/firewall.sh; source /tmp/firewall_ufw.sh; source /tmp/docker_firewall.sh
  export SOVIEZ_FW_PREFER_UFW=1
  soviez_fw_apply_soviez_policy ufw
  ufw reload
  ufw status | head -1 | grep -Eqi "Status:[[:space:]]*active"
'
# Guest "reboot" simulation: remount policy by re-apply after stop/start of guest container
docker stop "${rid}-fw" >/dev/null
docker start "${rid}-fw" >/dev/null
sleep 1
docker exec "${rid}-fw" bash -lc '
  set -euo pipefail
  source /tmp/firewall.sh; source /tmp/firewall_ufw.sh; source /tmp/docker_firewall.sh
  export SOVIEZ_FW_PREFER_UFW=1
  # After container start, re-apply is idempotent (reboot survival of managed rules)
  soviez_fw_apply_soviez_policy ufw
  ufw status | head -1 | grep -Eqi "Status:[[:space:]]*active"
  if ufw status | grep -q 8069; then exit 1; fi
'
echo PASS
