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

echo "TEST-SEC S1 idempotency"
PG="${PREFIX}-pg"
ADMIN_PASS="$(soviez_sec_pg_gen_password 24)"
APP_PASS="$(soviez_sec_pg_gen_password 24)"
docker network create "${PREFIX}-net" >/dev/null
docker run -d --name "$PG" --network "${PREFIX}-net" \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
for i in $(seq 1 60); do docker exec "$PG" pg_isready -U soviez_admin >/dev/null 2>&1 && break; sleep 1; done
soviez_sec_pg_provision_least_privilege "$PG" soviez_admin "$ADMIN_PASS" soviez_app "$APP_PASS" "idemdb"
soviez_sec_pg_provision_least_privilege "$PG" soviez_admin "$ADMIN_PASS" soviez_app "$APP_PASS" "idemdb"
soviez_sec_pg_assert_app_role_safe "$PG" soviez_admin "$ADMIN_PASS" soviez_app
echo "PASS idempotency"
