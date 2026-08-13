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

echo "TEST-SEC-005 pg network isolation (no public publish)"
PG="${PREFIX}-pg"
ADMIN_PASS="$(soviez_sec_pg_gen_password 24)"
docker network create "${PREFIX}-net" >/dev/null
docker run -d --name "$PG" --network "${PREFIX}-net" \
  -e POSTGRES_USER=soviez_admin -e POSTGRES_PASSWORD="$ADMIN_PASS" -e POSTGRES_DB=postgres \
  postgres:16 >/dev/null
soviez_sec_pg_assert_no_public_publish "$PG"
echo "PASS TEST-SEC-005"
