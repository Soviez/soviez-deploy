#!/usr/bin/env bash
# Shared Phase 19 certification fixtures (disposable).
# shellcheck shell=bash

soviez_p19_cert_env() {
  export SOVIEZ_PHASE19_CERTIFICATION=1
  export SOVIEZ_PHASE19_REQUIRE_REAL_MTLS=1
  export SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES=1
  export SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING=1
  export SOVIEZ_PHASE19_REQUIRE_REAL_STAGE=1
  export SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER=1
  export SOVIEZ_PHASE19_FORBID_FIXTURE_ERP=1
  export SOVIEZ_PHASE19_FORBID_FIXTURE_DB=1
  export SOVIEZ_MIG_TRANSFER_LOCAL=0
  export SOVIEZ_MIG_FORCE_FIXTURE_DB=0
  export SOVIEZ_MIG_FREEZE_FIXTURE=0
  export SOVIEZ_MIG_REAL_ERP_STAGING=1
  export SOVIEZ_MIG_ASSUME_YES=1
  export SOVIEZ_CLI_YES=1
  export SOVIEZ_MIG_TLS_FIXTURE=1
  export SOVIEZ_TEST_MODE=1
  export SOVIEZ_MIG_FREEZE_WATCHDOG="${SOVIEZ_MIG_FREEZE_WATCHDOG:-0}"
  export SOVIEZ_MIG_FREEZE_KEEP_GUARD=1
  export SOVIEZ_MIG_ERP_IMAGE="${SOVIEZ_MIG_ERP_IMAGE:-${SOVIEZ_TEST_ERP_CURRENT_IMAGE:-soviez-test/cert-current}}"
  export SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase19-disposable-migration-secret-not-production}"
}

soviez_p19_pair_bootstrap() {
  local prod="${1:-prod-p19-cert}" lic="${2:-lic-p19-cert}" domain="${3:-p19cert.example.test}"
  local digest="sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$digest"
  export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
  export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
  export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
  export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
  SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'$prod','environment_id':'$prod','license_id':'$lic','database_uuid':'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','image_digest':'$digest','domain':'$domain','erp_version':'18.0','postgresql_major':'16','database_name':'soviez_src'}))")"
  export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":5000000,"filestore_bytes":1000000,"addon_bytes":100000,"configuration_bytes":1000,"file_count":20,"inode_estimate":200,"estimated_transfer_bytes":7000000,"largest_components":[]}'
  export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$domain\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false}"
  export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"backup_id":"bak-p19-cert","classification":"recent_verified","latest_verified_age_seconds":10,"status":"VERIFIED"}'
  export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'
  DISC="$(soviez_migration_discover_run "$prod")"
  BOOT="$(soviez_migration_bootstrap_run 1)"
  PAIR="$(soviez_migration_pair_run "$prod" "$(soviez_json_get "$BOOT" bootstrap_code)" \
    "$(soviez_json_get "$DISC" identity.host_identity.fingerprint)" \
    "$(soviez_json_get "$BOOT" public_fingerprint)" "$lic" "$prod" "$(soviez_json_get "$BOOT" bootstrap_id)" 1)"
  PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"
  ROUTING_ID="$(soviez_migration_new_id rplan)"
  mkdir -p "$(soviez_migration_routing_plan_dir "$ROUTING_ID")"
  python3 - <<PY
import json, datetime
p="$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"
open(p,"w").write(json.dumps({
  "plan_id":"$ROUTING_ID","migration_pair_id":"$PAIR_ID","result":"PASS",
  "issued_at":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at":(datetime.datetime.utcnow()+datetime.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$(soviez_migration_routing_plan_dir "$ROUTING_ID")/object.json"
  export PAIR_ID ROUTING_ID
}

soviez_p19_start_pg() {
  local name="${1:-soviez-p19-cert-pg}"
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" \
    -e POSTGRES_PASSWORD=odoo -e POSTGRES_USER=odoo -e POSTGRES_DB=postgres \
    postgres:16 >/dev/null
  local i
  for i in $(seq 1 60); do
    docker exec "$name" pg_isready -U odoo >/dev/null 2>&1 && break
    sleep 1
  done
  # Synthetic Odoo-like schema + Stage DB
  docker exec -e PGPASSWORD=odoo "$name" psql -U odoo -d postgres -c "CREATE DATABASE soviez_src;" >/dev/null
  docker exec -e PGPASSWORD=odoo "$name" psql -U odoo -d soviez_src -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE ir_config_parameter(id serial primary key, key text, value text);
INSERT INTO ir_config_parameter(key,value) VALUES ('database.uuid','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');
CREATE TABLE ir_module_module(id serial primary key, name text, state text);
INSERT INTO ir_module_module(name,state) VALUES ('base','installed'),('web','installed'),('local_license_guard','installed');
CREATE TABLE ir_attachment(id serial primary key, name text, store_fname text, checksum text);
INSERT INTO ir_attachment(name,store_fname,checksum) VALUES ('logo.png','ab/cd/logo.png','abc123');
CREATE TABLE res_partner(id serial primary key, name text);
INSERT INTO res_partner(name) VALUES ('Cert Partner');
SQL
  docker exec -e PGPASSWORD=odoo "$name" psql -U odoo -d postgres -c "CREATE DATABASE soviez_stage_eligible;" >/dev/null
  docker exec -e PGPASSWORD=odoo "$name" psql -U odoo -d soviez_stage_eligible -c \
    "CREATE TABLE stage_marker(id int primary key, note text); INSERT INTO stage_marker VALUES (1,'eligible');" >/dev/null
  export SOVIEZ_MIG_PG_DUMP_CID="$name"
  export SOVIEZ_MIG_PG_RESTORE_CID="$name"
  export SOVIEZ_MIG_PG_PASSWORD=odoo
  export SOVIEZ_MIG_PG_USER=odoo
  export SOVIEZ_MIG_SOURCE_DB_NAME=soviez_src
  printf '%s\n' "$name"
}

soviez_p19_cleanup_pg() {
  local name="${1:-}"
  [[ -n "$name" ]] && docker rm -f "$name" >/dev/null 2>&1 || true
}
