#!/usr/bin/env bash
# TEST-SEC: Odoo schema/module ops under least-privilege app role + loopback publish + proxy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/erp_release_fixture.sh"
s1_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
RUN_ID="$(s1_run_id)"
PREFIX="soviez-s1-${RUN_ID}"
REPORT_DIR="${TMPDIR:-/tmp}/${PREFIX}-report"
mkdir -p "$REPORT_DIR"
cleanup() {
  s1_cleanup_containers "$PREFIX" 2>/dev/null || true
  docker network rm "${PREFIX}-net" >/dev/null 2>&1 || true
  rm -rf "$REPORT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "TEST-SEC Odoo functional least-privilege + reverse proxy"

IMAGE="${SOVIEZ_S1_ERP_IMAGE:-}"
if [[ -z "$IMAGE" ]]; then
  if declare -F soviez_test_erp_fixture_tags_ensure >/dev/null 2>&1; then
    soviez_test_erp_fixture_tags_ensure >/dev/null 2>&1 || true
    IMAGE="${SOVIEZ_TEST_ERP_CURRENT_IMAGE:-}"
  fi
  for t in "$IMAGE" soviez-erp:18.0.1.01.5-local-release-candidate-pass5; do
    [[ -n "$t" ]] && docker image inspect "$t" >/dev/null 2>&1 && { IMAGE="$t"; break; }
  done
fi
[[ -n "$IMAGE" ]] || { echo "FAIL no Soviez ERP image available" >&2; exit 1; }

NET="${PREFIX}-net"
PG="${PREFIX}-pg"
ERP="${PREFIX}-erp"
PROXY="${PREFIX}-ngx"
ADMIN_PASS="$(soviez_sec_pg_gen_password 32)"
APP_PASS="$(soviez_sec_pg_gen_password 32)"
MASTER_PASS="$(soviez_sec_pg_gen_password 32)"
DBNAME="s1odoo"

docker network create "$NET" >/dev/null
docker run -d --name "$PG" --network "$NET" --network-alias db \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 90); do
  docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1

soviez_sec_pg_provision_least_privilege "$PG" soviez_admin "$ADMIN_PASS" soviez_app "$APP_PASS" "$DBNAME"

CONF_HOST="${REPORT_DIR}/tenant.conf"
cat > "$CONF_HOST" <<EOF
[options]
admin_passwd = ${MASTER_PASS}
db_host = db
db_port = 5432
db_user = soviez_app
db_password = ${APP_PASS}
db_name = ${DBNAME}
list_db = False
dbfilter = ^${DBNAME}\$
proxy_mode = True
addons_path = addons,odoo/addons
without_demo = all
http_port = 8069
EOF
chmod 600 "$CONF_HOST"

# ERP: loopback publish only
MIG_SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
docker run -d --name "$ERP" --network "$NET" --network-alias odoo \
  -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" \
  -p "127.0.0.1:18080:8069" \
  --entrypoint bash "$IMAGE" -lc 'sleep infinity' >/dev/null
docker cp "$CONF_HOST" "${ERP}:/tmp/tenant.conf" >/dev/null

# Module install as app role (schema evolution proof)
set +e
docker exec "$ERP" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /tmp/tenant.conf -d ${DBNAME} --without-demo=all -i base,web --stop-after-init" \
  >"${REPORT_DIR}/init.log" 2>&1
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  # retry once (image path variants)
  set +e
  docker exec "$ERP" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /tmp/tenant.conf -d ${DBNAME} --without-demo=all -i base --stop-after-init" \
    >>"${REPORT_DIR}/init.log" 2>&1
  rc=$?
  set -e
fi
[[ $rc -eq 0 ]] || { echo "FAIL Odoo module init under app role"; tail -40 "${REPORT_DIR}/init.log" >&2; exit 1; }

# Prove tables created by app role ownership
owner="$(docker exec -e PGPASSWORD="$APP_PASS" "$PG" psql -U soviez_app -d "$DBNAME" -Atc \
  "SELECT pg_catalog.pg_get_userbyid(relowner) FROM pg_class WHERE relname='ir_module_module' LIMIT 1;" | tr -d '[:space:]')"
[[ "$owner" == "soviez_app" ]] || { echo "FAIL unexpected table owner=$owner" >&2; exit 1; }

# Start HTTP
docker exec -d "$ERP" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /tmp/tenant.conf -d ${DBNAME} --http-interface=0.0.0.0 --http-port=8069 > /tmp/http.log 2>&1"
login_code=000
for i in $(seq 1 90); do
  login_code="$(docker exec "$ERP" python3 -c 'import urllib.request
try:
 r=urllib.request.urlopen("http://127.0.0.1:8069/web/login", timeout=2); print(r.status)
except Exception:
 print("000")' 2>/dev/null | tr -d '\r' | tail -1)"
  [[ "$login_code" == "200" ]] && break
  sleep 2
done
[[ "$login_code" == "200" ]] || { echo "FAIL /web/login got ${login_code}"; docker exec "$ERP" tail -30 /tmp/http.log >&2 || true; exit 1; }

# Nginx reverse proxy container → loopback Odoo via docker network
docker run -d --name "$PROXY" --network "$NET" -p "127.0.0.1:18081:80" nginx:1.27-alpine >/dev/null
docker exec "$PROXY" sh -c 'cat > /etc/nginx/conf.d/default.conf <<EOF
server {
  listen 80;
  location / {
    proxy_pass http://odoo:8069;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
nginx -s reload' >/dev/null 2>&1 || docker exec "$PROXY" nginx -s reload >/dev/null 2>&1 || true
# From host: proxy reachable on loopback (retry — nginx/Odoo race under load)
proxy_code=000
for i in $(seq 1 45); do
  proxy_code="$(python3 -c 'import urllib.request
try:
 req=urllib.request.Request("http://127.0.0.1:18081/web/login", headers={"Host":"localhost"})
 r=urllib.request.urlopen(req, timeout=5); print(r.status)
except Exception:
 print("000")' 2>/dev/null | tr -d '\r' | tail -1)"
  [[ "$proxy_code" == "200" ]] && break
  sleep 2
done
[[ "$proxy_code" == "200" ]] || { echo "FAIL reverse proxy login got ${proxy_code}" >&2; docker exec "$PROXY" nginx -t >&2 || true; docker exec "$ERP" tail -20 /tmp/http.log >&2 || true; exit 1; }

# Containment asserts
soviez_sec_pg_assert_app_role_safe "$PG" soviez_admin "$ADMIN_PASS" soviez_app postgres
soviez_sec_pg_prove_copy_program_denied "$PG" soviez_app "$APP_PASS" "$DBNAME"
soviez_sec_pg_assert_no_public_publish "$PG"
soviez_sec_odoo_assert_no_public_direct_ports "$ERP"
soviez_sec_docker_assert_container_baseline "$ERP" odoo
soviez_sec_docker_assert_container_baseline "$PG" postgres

# Gate overall
export SOVIEZ_SEC_MODE=stage
export SOVIEZ_SEC_PG_CONTAINER="$PG"
export SOVIEZ_SEC_ODOO_CONTAINER="$ERP"
export SOVIEZ_SEC_PG_ADMIN_USER=soviez_admin
export SOVIEZ_SEC_PG_ADMIN_PASS="$ADMIN_PASS"
export SOVIEZ_SEC_PG_APP_USER=soviez_app
export SOVIEZ_SEC_PG_APP_PASS="$APP_PASS"
export SOVIEZ_SEC_ODOO_CONF="$CONF_HOST"
export SOVIEZ_SEC_REQUIRE_HTTPS=0
export SOVIEZ_SEC_PG_DB="$DBNAME"
export SOVIEZ_SEC_REPORT_DIR="$REPORT_DIR/gate"
soviez_security_validate_critical_containment

echo "PASS Odoo functional least-privilege + reverse proxy"
