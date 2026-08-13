#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
rid="$(s2_run_id)"
trap 's2_cleanup_containers "$rid"' EXIT

docker network create "${rid}-net" >/dev/null
docker run -d --name "${rid}-pg" --network "${rid}-net" --network-alias db \
  -e POSTGRES_PASSWORD=s2test -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
docker run -d --name "${rid}-web" --network "${rid}-net" --network-alias odoo \
  -p 127.0.0.1:28069:8069 hashicorp/http-echo:1.0 -listen=:8069 -text=ok >/dev/null
docker run -d --name "${rid}-probe" --network "${rid}-net" busybox:1.36 sleep 3600 >/dev/null

# Container DNS Odoo→PG / probe→db
sleep 2
docker exec "${rid}-probe" nslookup db >/dev/null 2>&1 \
  || docker exec "${rid}-probe" ping -c1 -W2 db >/dev/null 2>&1 \
  || docker exec "${rid}-probe" wget -q -O- --timeout=2 http://db:5432 >/dev/null 2>&1 \
  || { echo "FAIL container DNS to db" >&2; exit 1; }

# Required outbound (best-effort — do not fail S2 if sandbox blocks)
docker exec "${rid}-probe" wget -q -O- --timeout=5 http://1.1.1.1 >/dev/null 2>&1 \
  || docker exec "${rid}-probe" wget -q -O- --timeout=5 https://example.com >/dev/null 2>&1 \
  || echo "WARN outbound best-effort skipped"

pubs="$(docker port "${rid}-web" 8069)"
echo "$pubs" | grep -q '127.0.0.1'
if echo "$pubs" | grep -q '0.0.0.0'; then
  echo "FAIL public bind" >&2
  exit 1
fi

# External reachability: from probe, cannot treat host-loopback publish as cluster-public.
# Prove docker inspect HostIp is loopback (not 0.0.0.0).
hip="$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8069/tcp") 0).HostIp}}' "${rid}-web")"
[[ "$hip" == "127.0.0.1" ]]

# Docker restart resilience
docker restart "${rid}-web" "${rid}-pg" >/dev/null
sleep 3
docker exec "${rid}-probe" nslookup db >/dev/null 2>&1 \
  || docker exec "${rid}-probe" ping -c1 -W2 db >/dev/null 2>&1 \
  || { echo "FAIL DNS after docker restart" >&2; exit 1; }
pubs2="$(docker port "${rid}-web" 8069)"
echo "$pubs2" | grep -q '127.0.0.1'

export SOVIEZ_SEC_MODE=production
export SOVIEZ_SEC_ODOO_CONTAINER="${rid}-web"
export SOVIEZ_SEC_PG_CONTAINER="${rid}-pg"
export SOVIEZ_SEC_REPORT_DIR
SOVIEZ_SEC_REPORT_DIR="$(mktemp -d)"
export SOVIEZ_FW_OPTIONAL=1
export SOVIEZ_SEC_GATE_LABEL=S2
soviez_security_validate_host_edge

tmp="$(mktemp)"
soviez_nginx_s2_render_hardened "s2.local" "127.0.0.1:28069" "" "" "$tmp" http_only
soviez_nginx_s2_validate_syntax "$tmp"
rm -f "$tmp"

echo PASS
