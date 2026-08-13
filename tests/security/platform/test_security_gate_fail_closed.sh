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

echo "TEST-SEC gate fail-closed"
# UNKNOWN blocks when containers missing
export SOVIEZ_SEC_MODE=production
export SOVIEZ_SEC_PG_CONTAINER="${PREFIX}-missing"
export SOVIEZ_SEC_ODOO_CONTAINER="${PREFIX}-missing2"
export SOVIEZ_SEC_PG_ADMIN_PASS="x"
export SOVIEZ_SEC_REPORT_DIR="$(mktemp -d)"
if soviez_security_validate_critical_containment; then
  echo "FAIL expected UNKNOWN/FAIL"; exit 1
fi
# SUPERUSER app role fails
PG="${PREFIX}-pg"
ADMIN_PASS="$(soviez_sec_pg_gen_password 24)"
docker network create "${PREFIX}-net" >/dev/null
docker run -d --name "$PG" --network "${PREFIX}-net" \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 60); do docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1 && break; sleep 1; done
docker exec -e PGPASSWORD="$ADMIN_PASS" "$PG" psql -U soviez_admin -d postgres -c \
  "CREATE ROLE soviez_app LOGIN PASSWORD 'SafeAppPass999!' SUPERUSER;" >/dev/null
WEB="${PREFIX}-web"
docker run -d --name "$WEB" --network "${PREFIX}-net" -p "127.0.0.1:18071:8069" busybox:1.36 sleep 3600 >/dev/null
CONF="$(mktemp)"
cat > "$CONF" <<EOF
[options]
proxy_mode = True
list_db = False
dbfilter = ^production$
EOF
export SOVIEZ_SEC_PG_CONTAINER="$PG"
export SOVIEZ_SEC_ODOO_CONTAINER="$WEB"
export SOVIEZ_SEC_PG_ADMIN_PASS="$ADMIN_PASS"
export SOVIEZ_SEC_PG_APP_PASS="SafeAppPass999!"
export SOVIEZ_SEC_ODOO_CONF="$CONF"
if soviez_security_validate_critical_containment; then
  echo "FAIL SUPERUSER should fail gate"; exit 1
fi
rm -f "$CONF"
echo "PASS gate fail-closed"
