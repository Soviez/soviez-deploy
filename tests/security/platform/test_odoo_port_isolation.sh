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

echo "TEST-SEC-006 odoo port isolation"
NET="${PREFIX}-net"
LOOP="${PREFIX}-loop"
PUB="${PREFIX}-pub"
docker network create "$NET" >/dev/null
# Loopback publish OK
docker run -d --name "$LOOP" --network "$NET" -p "127.0.0.1:18069:8069" \
  nginx:alpine >/dev/null 2>&1 || docker run -d --name "$LOOP" --network "$NET" -p "127.0.0.1:18069:8069" \
  busybox:1.36 sleep 3600 >/dev/null
# busybox may not listen; we only assert bindings
soviez_sec_odoo_assert_no_public_direct_ports "$LOOP"
# Public publish must FAIL assert
docker run -d --name "$PUB" --network "$NET" -p "18070:8069" \
  busybox:1.36 sleep 3600 >/dev/null
if soviez_sec_odoo_assert_no_public_direct_ports "$PUB"; then
  echo "FAIL expected public publish to fail"; exit 1
fi
echo "PASS TEST-SEC-006"
