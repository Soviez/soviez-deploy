#!/usr/bin/env bash
# S5 — controlled network fault injection (DNS/outbound/ports). Host firewall untouched.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SEC_S5_EVIDENCE_ROOT="${TMPDIR:-/tmp}/soviez-s5-netfault-$$"
mkdir -p "$SOVIEZ_SEC_S5_EVIDENCE_ROOT"
rid="$(s5_run_id)"
trap 's5_cleanup_containers "$rid"; rm -rf "$SOVIEZ_SEC_S5_EVIDENCE_ROOT"' EXIT

docker network create "${rid}-net" >/dev/null
docker run -d --name "${rid}-pg" --network "${rid}-net" --network-alias db \
  -e POSTGRES_PASSWORD=s5 -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
docker run -d --name "${rid}-web" --network "${rid}-net" \
  -p 127.0.0.1:29169:8069 busybox:1.36 sleep 3600 >/dev/null
sleep 2
export SOVIEZ_SEC_ODOO_CONTAINER="${rid}-web"
export SOVIEZ_SEC_PG_CONTAINER="${rid}-pg"
export SOVIEZ_S5_REQUIRE_CONTAINERS=1

# Healthy baseline
[[ "$(soviez_s5_check_docker_dns)" == "PASS" ]] || exit 1
[[ "$(soviez_s5_check_ports_protected)" == "PASS" ]] || exit 1
echo "OK healthy DNS/ports"

# Inject DNS failure — update must not PASS
export SOVIEZ_S5_INJECT_DNS_FAIL=1
[[ "$(soviez_s5_check_dns || true)" == "FAIL" ]] || exit 1
unset SOVIEZ_S5_INJECT_DNS_FAIL

export SOVIEZ_S5_INJECT_OUTBOUND_FAIL=1
[[ "$(soviez_s5_check_outbound || true)" == "FAIL" ]] || exit 1
unset SOVIEZ_S5_INJECT_OUTBOUND_FAIL

export SOVIEZ_S5_INJECT_PUBLIC_PORT=1
[[ "$(soviez_s5_check_ports_protected || true)" == "FAIL" ]] || exit 1
unset SOVIEZ_S5_INJECT_PUBLIC_PORT

# Quarantine expected offline ≠ failure
export SOVIEZ_S5_QUARANTINE=1
[[ "$(soviez_s5_check_outbound)" == "EXPECTED_OFFLINE" ]] || exit 1
unset SOVIEZ_S5_QUARANTINE
echo "OK fault inject + quarantine expected-offline"

echo PASS
