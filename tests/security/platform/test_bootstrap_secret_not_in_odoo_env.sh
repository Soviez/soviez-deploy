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

echo "TEST-SEC bootstrap secret not in odoo env"
PG="${PREFIX}-pg"
WEB="${PREFIX}-web"
NET="${PREFIX}-net"
ADMIN_PASS="$(soviez_sec_pg_gen_password 24)"
APP_PASS="$(soviez_sec_pg_gen_password 24)"
docker network create "$NET" >/dev/null
docker run -d --name "$PG" --network "$NET" \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 60); do docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1 && break; sleep 1; done
soviez_sec_pg_provision_least_privilege "$PG" soviez_admin "$ADMIN_PASS" soviez_app "$APP_PASS"
# Web gets only app password, never admin
docker run -d --name "$WEB" --network "$NET" -p "127.0.0.1:18073:8069" \
  -e POSTGRES_PASSWORD="$APP_PASS" \
  busybox:1.36 sleep 3600 >/dev/null
env_blob="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$WEB")"
printf '%s' "$env_blob" | grep -Fq -- "$ADMIN_PASS" && { echo FAIL; exit 1; }
CONF="$(mktemp)"; cat > "$CONF" <<EOF
[options]
proxy_mode = True
list_db = False
dbfilter = ^x$
EOF
export SOVIEZ_SEC_MODE=production
export SOVIEZ_SEC_PG_CONTAINER="$PG"
export SOVIEZ_SEC_ODOO_CONTAINER="$WEB"
export SOVIEZ_SEC_PG_ADMIN_PASS="$ADMIN_PASS"
export SOVIEZ_SEC_PG_APP_PASS="$APP_PASS"
export SOVIEZ_SEC_ODOO_CONF="$CONF"
export SOVIEZ_SEC_REPORT_DIR="$(mktemp -d)"
soviez_security_validate_critical_containment
rm -f "$CONF"
echo "PASS bootstrap secret isolation"
