#!/usr/bin/env bash
# TEST-SEC-019 — real Docker internal network blocks egress; PG internal works.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s4_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d)"
rid="$(s4_run_id)"
trap 'docker rm -f "${rid}-pg" "${rid}-probe" "${rid}-mail" >/dev/null 2>&1 || true
      qid=$(cat "$SOVIEZ_SEC_QUARANTINE_ROOT/.qid" 2>/dev/null || true)
      [[ -n "$qid" ]] && soviez_q_network_cleanup "$qid" || true
      rm -rf "$SOVIEZ_SEC_QUARANTINE_ROOT"' EXIT

export SOVIEZ_Q_TRUST=EXTERNAL_UNKNOWN
qid="$(soviez_q_create)"
echo "$qid" >"$SOVIEZ_SEC_QUARANTINE_ROOT/.qid"
soviez_q_generate_fresh_secrets "$qid" >/dev/null
net="$(soviez_q_network_create "$qid")"

# PG on quarantine network
docker run -d --name "${rid}-pg" --network "$net" --network-alias db \
  -e POSTGRES_PASSWORD=s4test -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
docker run -d --name "${rid}-probe" --network "$net" busybox:1.36 sleep 3600 >/dev/null

for i in $(seq 1 30); do
  docker exec "${rid}-pg" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done

# Internal DB connectivity
docker exec "${rid}-probe" nc -z -w 2 db 5432

# External egress blocked
soviez_q_network_prove_egress_blocked "$qid" "${rid}-probe"
soviez_q_mail_prove_no_external "$qid" "${rid}-probe"
soviez_q_webhook_prove_blocked "$qid" "${rid}-probe"
soviez_q_zatca_outbound_prove_blocked "$qid" "${rid}-probe"

# Public ingress: quarantine containers have no host publish of 8069
ports="$(docker port "${rid}-pg" 2>/dev/null || true)"
[[ -z "$ports" ]]

# Cron neutralization config present
soviez_q_odoo_quarantine_conf_snippet | grep -q 'max_cron_threads = 0'

# Seed cron marker table; with no cron worker, marker stays 0
docker exec -e PGPASSWORD=s4test "${rid}-pg" psql -U soviez_admin -d postgres -v ON_ERROR_STOP=1 \
  -c "$(soviez_q_cron_marker_seed_sql)" >/dev/null
soviez_q_assert_cron_not_fired "${rid}-pg" soviez_admin s4test postgres

echo PASS
