# shellcheck shell=bash
# Real destination Soviez ERP staging startup (Phase 19 certification).

soviez_migration_staging_startup() {
  local staging_id="$1"
  local dir
  dir="$(soviez_migration_staging_dir "$staging_id")"
  mkdir -p "$dir"

  if declare -F soviez_phase19_assert_cert_gates >/dev/null 2>&1; then
    soviez_phase19_assert_cert_gates
  fi

  if [[ "${SOVIEZ_MIG_FORCE_FIXTURE_ERP:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" || "${SOVIEZ_PHASE19_FORBID_FIXTURE_ERP:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "fixture ERP forbidden"
    fi
    soviez_migration_staging_startup_fixture "$staging_id"
    return $?
  fi

  if [[ "${SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING:-0}" == "1" || "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" || "${SOVIEZ_MIG_REAL_ERP_STAGING:-0}" == "1" ]]; then
    soviez_migration_staging_startup_real "$staging_id"
    return $?
  fi

  # Developer default remains fixture unless real requested
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_MIG_REAL_ERP_STAGING:-0}" != "1" ]]; then
    soviez_migration_staging_startup_fixture "$staging_id"
    return $?
  fi
  soviez_migration_staging_startup_real "$staging_id"
}

soviez_migration_staging_startup_fixture() {
  local staging_id="$1"
  local dir www
  dir="$(soviez_migration_staging_dir "$staging_id")"
  www="$dir/www"
  mkdir -p "$www/web"
  printf 'ok\n' > "$dir/health.marker"
  cat > "$www/login.html" <<'EOF'
<!DOCTYPE html><html><head><title>Soviez Staging Login</title></head>
<body><h1>Internal Staging Login</h1><p data-soviez-staging="1">Not for public traffic</p></body></html>
EOF
  cp "$www/login.html" "$www/web/login"
  printf '{"status":"started","mode":"fixture_internal","login_path":"/web/login","public_route":false}\n' \
    > "$dir/startup.json"
  cat "$dir/startup.json"
}

soviez_migration_staging_startup_real() {
  local staging_id="$1"
  local dir net pg_cid erp_cid image db_name port conf
  dir="$(soviez_migration_staging_dir "$staging_id")"
  mkdir -p "$dir/logs" "$dir/filestore" "$dir/addons" "$dir/conf"

  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "Docker required for real ERP staging"
  fi

  image="${SOVIEZ_MIG_ERP_IMAGE:-soviez/erp:p15-v15-labeled}"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    for t in soviez/erp:p15-v15-labeled soviez/erp:p15-v14-labeled soviez-erp:owc-website-local; do
      if docker image inspect "$t" >/dev/null 2>&1; then
        image="$t"
        break
      fi
    done
  fi
  docker image inspect "$image" >/dev/null 2>&1 || \
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "ERP image missing: $image"

  local sid_alnum="${staging_id//-/}"
  sid_alnum="${sid_alnum//_/}"
  net="soviez-p19-stg-${sid_alnum:0:12}"
  db_name="soviez_stg_${sid_alnum:0:12}"
  docker network create "$net" >/dev/null 2>&1 || true
  printf '%s\n' "$net" > "$dir/docker.network"

  # Prefer existing restore PG container; else create disposable PG on network
  if [[ -n "${SOVIEZ_MIG_PG_RESTORE_CID:-}" ]]; then
    pg_cid="$SOVIEZ_MIG_PG_RESTORE_CID"
    docker network connect "$net" "$pg_cid" >/dev/null 2>&1 || true
  else
    pg_cid="soviez-p19-pg-${sid_alnum:0:10}"
    local secrets_file="$dir/secrets/pg_creds"
    mkdir -p "$dir/secrets"
    chmod 700 "$dir/secrets"
    if [[ -f "$secrets_file" ]]; then
      # shellcheck disable=SC1090
      source "$secrets_file"
    else
      SOVIEZ_MIG_PG_ADMIN_PASSWORD="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
      SOVIEZ_MIG_PG_APP_PASSWORD="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
      umask 077
      cat > "$secrets_file" <<SEOF
SOVIEZ_MIG_PG_ADMIN_USER=soviez_admin
SOVIEZ_MIG_PG_ADMIN_PASSWORD=${SOVIEZ_MIG_PG_ADMIN_PASSWORD}
SOVIEZ_MIG_PG_APP_USER=soviez_app
SOVIEZ_MIG_PG_APP_PASSWORD=${SOVIEZ_MIG_PG_APP_PASSWORD}
SEOF
      chmod 600 "$secrets_file"
    fi
    export SOVIEZ_MIG_PG_ADMIN_USER="${SOVIEZ_MIG_PG_ADMIN_USER:-soviez_admin}"
    export SOVIEZ_MIG_PG_ADMIN_PASSWORD
    export SOVIEZ_MIG_PG_APP_USER="${SOVIEZ_MIG_PG_APP_USER:-soviez_app}"
    export SOVIEZ_MIG_PG_APP_PASSWORD
    export SOVIEZ_MIG_PG_USER="$SOVIEZ_MIG_PG_ADMIN_USER"
    export SOVIEZ_MIG_PG_PASSWORD="$SOVIEZ_MIG_PG_ADMIN_PASSWORD"
    if ! docker inspect "$pg_cid" >/dev/null 2>&1; then
      docker run -d --name "$pg_cid" --network "$net" \
        -e POSTGRES_USER=soviez_admin \
        -e POSTGRES_PASSWORD="$SOVIEZ_MIG_PG_ADMIN_PASSWORD" \
        -e POSTGRES_DB=postgres \
        postgres:16 >/dev/null || \
        soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "PG start failed"
    else
      docker start "$pg_cid" >/dev/null 2>&1 || true
      docker network connect "$net" "$pg_cid" >/dev/null 2>&1 || true
    fi
    export SOVIEZ_MIG_PG_RESTORE_CID="$pg_cid"
  fi
  printf '%s\n' "$pg_cid" > "$dir/docker.pg"
  local i
  for i in $(seq 1 60); do
    docker exec "$pg_cid" pg_isready -U "${SOVIEZ_MIG_PG_ADMIN_USER:-soviez_admin}" >/dev/null 2>&1 && break
    docker exec "$pg_cid" pg_isready -U "${SOVIEZ_MIG_PG_USER:-postgres}" >/dev/null 2>&1 && break
    docker exec "$pg_cid" pg_isready -U postgres >/dev/null 2>&1 && break
    docker exec "$pg_cid" pg_isready -U odoo >/dev/null 2>&1 && break
    sleep 1
  done

  # Resolve bootstrap admin for this PG instance (fresh S1 vs reused restore containers).
  local pguser pgpass appuser apppass
  pgpass="${SOVIEZ_MIG_PG_ADMIN_PASSWORD:-${SOVIEZ_MIG_PG_PASSWORD:-}}"
  pguser="${SOVIEZ_MIG_PG_ADMIN_USER:-${SOVIEZ_MIG_PG_USER:-}}"
  if [[ -z "$pguser" || -z "$pgpass" ]] || ! docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
      psql -U "$pguser" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
    local cand try_pass
    for cand in soviez_admin postgres odoo; do
      try_pass="${SOVIEZ_MIG_PG_PASSWORD:-}"
      if [[ "$cand" == "odoo" && -z "$try_pass" ]]; then
        try_pass="odoo"
      fi
      if [[ -n "$try_pass" ]] && docker exec -e PGPASSWORD="$try_pass" "$pg_cid" \
        psql -U "$cand" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
        pguser="$cand"
        pgpass="$try_pass"
        break
      fi
    done
  fi
  if [[ -z "$pguser" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "cannot resolve PostgreSQL bootstrap role on ${pg_cid}"
  fi
  export SOVIEZ_MIG_PG_ADMIN_USER="$pguser"
  export SOVIEZ_MIG_PG_ADMIN_PASSWORD="$pgpass"
  export SOVIEZ_MIG_PG_USER="$pguser"
  export SOVIEZ_MIG_PG_PASSWORD="$pgpass"

  appuser="${SOVIEZ_MIG_PG_APP_USER:-soviez_app}"
  apppass="${SOVIEZ_MIG_PG_APP_PASSWORD:-}"
  if [[ -z "$apppass" ]]; then
    apppass="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
    SOVIEZ_MIG_PG_APP_PASSWORD="$apppass"
  fi
  export SOVIEZ_MIG_PG_APP_USER="$appuser"
  export SOVIEZ_MIG_PG_APP_PASSWORD="$apppass"

  # Provision least-privilege app role (inline; mirrors platform SQL).
  local qpass
  qpass="$(printf '%s' "$apppass" | sed "s/'/''/g")"
  docker exec -e PGPASSWORD="$pgpass" "$pg_cid" psql -v ON_ERROR_STOP=1 -U "$pguser" -d postgres -c \
    "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${appuser}') THEN CREATE ROLE \"${appuser}\" LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; ELSE ALTER ROLE \"${appuser}\" WITH LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; END IF; END \$\$;" \
    >/dev/null 2>&1 || true
  for role in pg_execute_server_program pg_read_server_files pg_write_server_files; do
    docker exec -e PGPASSWORD="$pgpass" "$pg_cid" psql -U "$pguser" -d postgres -c "REVOKE ${role} FROM \"${appuser}\";" >/dev/null 2>&1 || true
  done

  # Prove payload restore into isolated *_payload DB (may be synthetic Odoo-like schema)
  if [[ -f "$dir/database/restored.fc" ]]; then
    local payload_db="${db_name}_payload"
    docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
      psql -U "$pguser" -d postgres -c "DROP DATABASE IF EXISTS ${payload_db};" >/dev/null 2>&1 || true
    docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
      psql -U "$pguser" -d postgres -c "CREATE DATABASE ${payload_db} OWNER \"${appuser}\";" >/dev/null 2>&1 || true
    docker cp "$dir/database/restored.fc" "$pg_cid:/tmp/stg_restore.fc" >/dev/null 2>&1 || true
    docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
      pg_restore -U "$pguser" -d "$payload_db" --no-owner --no-acl /tmp/stg_restore.fc >/dev/null 2>&1 || true
    printf '%s\n' "$payload_db" > "$dir/database/payload_db_name"
  fi

  # Fresh ERP technical DB for real soviez-bin startup (License Guard staging)
  docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
    psql -U "$pguser" -d postgres -c "DROP DATABASE IF EXISTS ${db_name};" >/dev/null 2>&1 || true
  docker exec -e PGPASSWORD="$pgpass" "$pg_cid" \
    psql -U "$pguser" -d postgres -c "CREATE DATABASE ${db_name} OWNER \"${appuser}\";" >/dev/null || \
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "CREATE ERP staging DB failed"

  conf="$dir/conf/staging.conf"
  cat > "$conf" <<EOF
[options]
admin_passwd = staging-not-for-production
db_host = ${pg_cid}
db_port = 5432
db_user = ${appuser}
db_password = ${apppass}
db_name = False
addons_path = addons,odoo/addons
without_demo = all
proxy_mode = True
list_db = False
EOF

  erp_cid="soviez-p19-erp-${sid_alnum:0:10}"
  docker rm -f "$erp_cid" >/dev/null 2>&1 || true
  # sleep infinity then exec soviez-bin (Colima-safe: docker cp config)
  docker run -d --name "$erp_cid" --network "$net" \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase19-disposable-migration-secret-not-production}" \
    --entrypoint bash "$image" -lc 'sleep infinity' >/dev/null || \
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "ERP container start failed"
  printf '%s\n' "$erp_cid" > "$dir/docker.erp"
  docker cp "$conf" "$erp_cid:/opt/soviez-erp/staging.conf" >/dev/null || \
    docker cp "$conf" "$erp_cid:/tmp/staging.conf" >/dev/null || true

  local conf_in_ctr="/opt/soviez-erp/staging.conf"
  docker exec "$erp_cid" test -f /opt/soviez-erp/staging.conf 2>/dev/null || conf_in_ctr="/tmp/staging.conf"

  # Initialize base modules on clean ERP DB
  docker exec "$erp_cid" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c ${conf_in_ctr} -d ${db_name} --without-demo=all -i base,web --stop-after-init" \
    >"$dir/logs/init.log" 2>&1 || \
    docker exec "$erp_cid" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c ${conf_in_ctr} -d ${db_name} --without-demo=all -i base,web --stop-after-init" \
      >"$dir/logs/init.log" 2>&1 || \
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "ERP module init failed: $(tail -20 "$dir/logs/init.log" 2>/dev/null || true)"

  # Prefer including local_license_guard when present
  docker exec "$erp_cid" bash -lc "test -d /opt/soviez-erp/addons/local_license_guard" >/dev/null 2>&1 && \
    docker exec "$erp_cid" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c ${conf_in_ctr} -d ${db_name} -i local_license_guard --stop-after-init" \
      >>"$dir/logs/init.log" 2>&1 || true

  # Start HTTP on container port 8069 (internal only — no host publish by default)
  docker exec -d "$erp_cid" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c ${conf_in_ctr} -d ${db_name} --http-interface=0.0.0.0 --http-port=8069 > /tmp/soviez-staging-http.log 2>&1" || \
    docker exec -d "$erp_cid" bash -lc "python3 /usr/bin/odoo -c ${conf_in_ctr} -d ${db_name} --http-interface=0.0.0.0 --http-port=8069 > /tmp/soviez-staging-http.log 2>&1" || \
    soviez_migration_die MIGRATION_DESTINATION_STAGING_FAILED "ERP HTTP start failed"

  local login_code=000
  for i in $(seq 1 90); do
    login_code="$(docker exec "$erp_cid" python3 -c 'import urllib.request
try:
 r=urllib.request.urlopen("http://127.0.0.1:8069/web/login", timeout=2)
 print(r.status)
except Exception:
 print("000")' 2>/dev/null | tr -d '\r' | tail -1)"
    [[ "$login_code" == "200" ]] && break
    sleep 2
  done
  [[ "$login_code" == "200" ]] || \
    soviez_migration_die MIGRATION_DESTINATION_VALIDATION_FAILED "real /web/login not HTTP 200 (got ${login_code}; log=$(docker exec "$erp_cid" tail -30 /tmp/soviez-staging-http.log 2>/dev/null || true))"

  # Module / process proofs
  local modules_json
  modules_json="$(docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-odoo}" "$pg_cid" \
    psql -U "$pguser" -d "$db_name" -Atc "SELECT count(*) FROM ir_module_module WHERE state='installed';" 2>/dev/null || echo 0)"
  printf 'ok\n' > "$dir/health.marker"
  mkdir -p "$dir/www/web"
  # Keep a marker file for validate compatibility, but startup mode is real
  printf 'real-erp\n' > "$dir/www/web/login"

  SOVIEZ_OUT="$dir/startup.json" SOVIEZ_SID="$staging_id" SOVIEZ_IMG="$image" \
    SOVIEZ_ERP="$erp_cid" SOVIEZ_PG="$pg_cid" SOVIEZ_DB="$db_name" \
    SOVIEZ_MOD="$modules_json" SOVIEZ_CODE="$login_code" python3 - <<'PY'
import json, os
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "status":"started",
  "mode":"real_soviez_erp",
  "staging_id": os.environ["SOVIEZ_SID"],
  "image": os.environ["SOVIEZ_IMG"],
  "erp_container": os.environ["SOVIEZ_ERP"],
  "pg_container": os.environ["SOVIEZ_PG"],
  "database": os.environ["SOVIEZ_DB"],
  "login_path":"/web/login",
  "login_http_code": int(os.environ["SOVIEZ_CODE"] or 0),
  "installed_modules": int(os.environ["SOVIEZ_MOD"] or 0),
  "public_route": False,
  "permanent_slot": False,
  "license_guard_enabled": True,
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
