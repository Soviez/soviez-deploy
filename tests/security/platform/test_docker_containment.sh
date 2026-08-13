#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s1_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
RUN_ID="$(s1_run_id)"
PREFIX="soviez-s1-${RUN_ID}"
cleanup() { s1_cleanup_containers "$PREFIX"; }
trap cleanup EXIT

echo "TEST-SEC-016 docker containment"
NET="${PREFIX}-net"
OK="${PREFIX}-ok"
docker network create "$NET" >/dev/null
docker run -d --name "$OK" --network "$NET" busybox:1.36 sleep 3600 >/dev/null
soviez_sec_docker_assert_container_baseline "$OK" odoo
# sock mount must fail baseline when present
SOCK="${PREFIX}-sock"
if docker run -d --name "$SOCK" --network "$NET" -v /var/run/docker.sock:/var/run/docker.sock \
  busybox:1.36 sleep 3600 >/dev/null 2>&1; then
  if soviez_sec_docker_assert_container_baseline "$SOCK" odoo; then
    echo "FAIL sock should fail"; exit 1
  fi
fi
# host network
HOSTC="${PREFIX}-host"
if docker run -d --name "$HOSTC" --network host busybox:1.36 sleep 3600 >/dev/null 2>&1; then
  if soviez_sec_docker_assert_container_baseline "$HOSTC" odoo; then
    echo "FAIL host net should fail"; exit 1
  fi
fi
echo "PASS TEST-SEC-016"
