#!/usr/bin/env bash
# S5 real Docker restart matrix: network, pg, http-echo web, busybox probe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SEC_S5_EVIDENCE_ROOT
SOVIEZ_SEC_S5_EVIDENCE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-s5-evid.XXXXXX")"
rid="$(s5_run_id)"
prefix="soviez-s5-${rid}"
host_port="$((28100 + RANDOM % 500))"
trap 's5_cleanup_containers "$prefix"; rm -rf "$SOVIEZ_SEC_S5_EVIDENCE_ROOT"' EXIT

docker network create "${prefix}-net" >/dev/null

# postgres as db alias
docker run -d --name "${prefix}-pg" --network "${prefix}-net" --network-alias db \
  -e POSTGRES_PASSWORD=s5 -e POSTGRES_USER=soviez_admin \
  postgres:16-alpine >/dev/null

# http-echo as web on loopback 28xxx:8069 (fallback: busybox if image lacks shell)
if ! docker run -d --name "${prefix}-web" --network "${prefix}-net" --network-alias web \
  -p "127.0.0.1:${host_port}:8069" \
  hashicorp/http-echo:1.0 -listen=:8069 -text=ok >/dev/null 2>&1; then
  docker rm -f "${prefix}-web" >/dev/null 2>&1 || true
  docker run -d --name "${prefix}-web" --network "${prefix}-net" --network-alias web \
    -p "127.0.0.1:${host_port}:8069" \
    busybox:1.36 sleep 3600 >/dev/null
fi

docker run -d --name "${prefix}-probe" --network "${prefix}-net" \
  busybox:1.36 sleep 3600 >/dev/null

# Prefer a DNS-capable container as Odoo role when http-echo has no shell tools.
web="${prefix}-web"
if ! docker exec "$web" sh -c 'getent hosts db >/dev/null 2>&1 || nslookup db >/dev/null 2>&1 || true' >/dev/null 2>&1; then
  # Recreate web as busybox with same loopback publish (bindings matter for ports check).
  docker rm -f "$web" >/dev/null 2>&1 || true
  docker run -d --name "${prefix}-web" --network "${prefix}-net" --network-alias web \
    -p "127.0.0.1:${host_port}:8069" \
    busybox:1.36 sleep 3600 >/dev/null
  web="${prefix}-web"
fi

for i in $(seq 1 40); do
  docker exec "${prefix}-pg" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done

export SOVIEZ_SEC_ODOO_CONTAINER="$web"
export SOVIEZ_SEC_PG_CONTAINER="${prefix}-pg"
export SOVIEZ_SEC_PG_HOST=db
export SOVIEZ_S5_DNS_TARGET=db
# External DNS may be blocked; skip external when validating restart matrix.
export SOVIEZ_S5_OFFLINE=1
export SOVIEZ_S5_PDF_N_A=1

op="${rid}-restart"
export SOVIEZ_S5_OP_ID="$op"
export SOVIEZ_S5_BASELINE_PHASE=pre
pre="$(soviez_s5_baseline_capture "$op")"
[[ -f "$pre" ]]

# DNS db from web + probe
dns="$(soviez_s5_check_dns "$web")"
[[ "$dns" == "PASS" || "$dns" == "SKIP" ]]
docker exec "${prefix}-probe" nslookup db >/dev/null 2>&1 \
  || docker exec "${prefix}-probe" ping -c1 -W2 db >/dev/null

ports="$(soviez_s5_check_ports_protected "$web" "${prefix}-pg")"
[[ "$ports" == "PASS" ]]
docker port "$web" 8069 | grep -q 127.0.0.1

pgc="$(soviez_s5_check_odoo_pg "$web" "${prefix}-pg")"
[[ "$pgc" == "PASS" || "$pgc" == "SKIP" ]]

# Docker restart via S5 helper
rst="$(soviez_s5_docker_restart_validate "$web" "${prefix}-pg" "${prefix}-probe")"
[[ "$rst" == "PASS" ]]

# Post-restart: DNS db, loopback ports, odoo→pg
dns2="$(soviez_s5_check_dns "$web")"
[[ "$dns2" == "PASS" || "$dns2" == "SKIP" ]]
ports2="$(soviez_s5_check_ports_protected "$web" "${prefix}-pg")"
[[ "$ports2" == "PASS" ]]
docker port "$web" 8069 | grep -q 127.0.0.1
pgc2="$(soviez_s5_check_odoo_pg "$web" "${prefix}-pg")"
[[ "$pgc2" == "PASS" || "$pgc2" == "SKIP" ]]
echo "OK post-restart matrix"

# Fault inject: DNS fail must FAIL
set +e
dns_fail="$(SOVIEZ_S5_INJECT_DNS_FAIL=1 soviez_s5_check_dns "$web" 2>/dev/null)"
dns_rc=$?
set -e
[[ "$dns_fail" == "FAIL" ]]
[[ "$dns_rc" -ne 0 ]]
echo "OK DNS inject FAIL"

echo PASS
