#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
rid="$(s2_run_id)"
trap 's2_cleanup_containers "$rid"' EXIT
# Public Odoo must fail gate
docker network create "${rid}-net" >/dev/null
docker run -d --name "${rid}-web" --network "${rid}-net" -p 0.0.0.0:18069:8069 busybox sleep 3600 >/dev/null
export SOVIEZ_SEC_MODE=production
export SOVIEZ_SEC_ODOO_CONTAINER="${rid}-web"
export SOVIEZ_SEC_REPORT_DIR="$(mktemp -d)"
export SOVIEZ_FW_OPTIONAL=1
export SOVIEZ_SEC_GATE_LABEL=S2
if soviez_security_validate_host_edge; then
  echo FAIL expected public odoo to block >&2
  exit 1
fi
echo PASS
