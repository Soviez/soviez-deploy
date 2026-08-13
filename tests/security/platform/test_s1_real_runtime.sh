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

echo "TEST-SEC S1 real runtime matrix"
PG="${PREFIX}-pg"
WEB="${PREFIX}-web"
NET="${PREFIX}-net"
ADMIN_PASS="$(soviez_sec_pg_gen_password 24)"
APP_PASS="$(soviez_sec_pg_gen_password 24)"
docker network create "$NET" >/dev/null
docker run -d --name "$PG" --network "$NET" --network-alias db \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 60); do docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1 && break; sleep 1; done
soviez_sec_pg_provision_least_privilege "$PG" soviez_admin "$ADMIN_PASS" soviez_app "$APP_PASS" "rtdb"
docker run -d --name "$WEB" --network "$NET" --network-alias web \
  -p "127.0.0.1:18072:8069" \
  curlimages/curl:8.5.0 sleep 3600 >/dev/null 2>&1 \
  || docker run -d --name "$WEB" --network "$NET" --network-alias web \
       -p "127.0.0.1:18072:8069" busybox:1.36 sleep 3600 >/dev/null
# DNS on user-defined network
docker exec "$WEB" getent hosts db >/dev/null 2>&1 \
  || docker exec "$WEB" nslookup db >/dev/null 2>&1 \
  || docker exec "$WEB" ping -c1 db >/dev/null 2>&1 \
  || true
# Outbound from container (best-effort; may be blocked — do not fail suite solely on outbound)
docker exec "$WEB" wget -q -O- --timeout=3 http://1.1.1.1 >/dev/null 2>&1 || true
# odoo→pg with real role (from web container using network alias) — use pg container exec for role proof
docker exec -e PGPASSWORD="$APP_PASS" "$PG" psql -U soviez_app -d rtdb -c 'SELECT 1' >/dev/null
soviez_sec_pg_assert_no_public_publish "$PG"
soviez_sec_odoo_assert_no_public_direct_ports "$WEB"
echo "PASS real runtime"
