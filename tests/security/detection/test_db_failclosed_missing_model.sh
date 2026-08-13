#!/usr/bin/env bash
# Fail-closed when required Odoo model missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_S3_REQUIRE_ODOO_SCHEMA=1

rid="$(s3_run_id)"
trap 'docker rm -f "${rid}-pg" >/dev/null 2>&1 || true' EXIT
docker run -d --name "${rid}-pg" -e POSTGRES_PASSWORD=s3test -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
for i in $(seq 1 30); do
  docker exec "${rid}-pg" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done

export SOVIEZ_SEC_PG_CONTAINER="${rid}-pg"
export SOVIEZ_SEC_PG_ADMIN_USER=soviez_admin
export SOVIEZ_SEC_PG_ADMIN_PASS=s3test
export SOVIEZ_SEC_PG_DB=postgres
export SOVIEZ_SEC_S3_EVIDENCE_ROOT
SOVIEZ_SEC_S3_EVIDENCE_ROOT="$(mktemp -d)"
ev="$(soviez_s3_evidence_init "s3-block")"
set +e
soviez_s3_db_scan "$ev" >/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]
echo PASS
