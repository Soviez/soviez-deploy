# shellcheck shell=bash
# Security Gate S1 — PostgreSQL least-privilege app role (bootstrap vs app).
#
# Bootstrap role default: soviez_admin (SOVIEZ_PG_ADMIN_USER)
# App role default:       soviez_app   (SOVIEZ_PG_APP_USER)
# Never pass bootstrap password to Odoo.

soviez_sec_pg_gen_password() {
  local len="${1:-32}"
  if ! [[ "$len" =~ ^[0-9]+$ ]] || [[ "$len" -lt 8 ]]; then
    len=32
  fi
  python3 -c "import secrets,string; a=string.ascii_letters+string.digits; print(''.join(secrets.choice(a) for _ in range(int('${len}'))))"
}

soviez_sec_pg_sql_escape_literal() {
  local s="$1"
  # Double single-quotes for SQL string literals (portable; avoid bash ${//} quote pitfalls).
  printf '%s' "$s" | sed "s/'/''/g"
}

soviez_sec_pg_ident_quote() {
  local s="$1"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

soviez_sec_pg_exec_admin() {
  local container="$1" admin_user="$2" admin_pass="$3" database="$4" sql="$5"
  if [[ -z "$container" || -z "$admin_user" || -z "$database" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: pg_exec_admin missing args" >&2
    return 1
  fi
  docker exec -e PGPASSWORD="$admin_pass" "$container" \
    psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$database" -tAc "$sql"
}

soviez_sec_pg_exec_as_role() {
  local container="$1" role_user="$2" role_pass="$3" database="$4" sql="$5"
  docker exec -e PGPASSWORD="$role_pass" "$container" \
    psql -v ON_ERROR_STOP=1 -U "$role_user" -d "$database" -tAc "$sql"
}

soviez_sec_pg_ensure_app_role() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="$5"
  local database="${6:-postgres}"

  [[ -n "$app_pass" ]] || { echo "[error] security:SEC_CRIT_WEAK_ADMIN_CREDENTIAL: app password required" >&2; return 1; }
  if declare -F soviez_sec_password_assert_not_weak >/dev/null 2>&1; then
    soviez_sec_password_assert_not_weak "$app_pass" "pg_app_role" || return 1
  fi

  local quser qpass iduser
  quser="$(soviez_sec_pg_sql_escape_literal "$app_user")"
  qpass="$(soviez_sec_pg_sql_escape_literal "$app_pass")"
  iduser="$(soviez_sec_pg_ident_quote "$app_user")"

  local sql
  sql=$(cat <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${quser}') THEN
    CREATE ROLE ${iduser} LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  ELSE
    ALTER ROLE ${iduser} WITH LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  END IF;
END
\$\$;
EOSQL
)
  soviez_sec_pg_exec_admin "$container" "$admin_user" "$admin_pass" "$database" "$sql" >/dev/null
}

soviez_sec_pg_ensure_database() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local db_name="$5"
  local maintenance_db="${6:-postgres}"

  [[ -n "$db_name" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: database name required" >&2; return 1; }

  local qdb iddb idowner
  qdb="$(soviez_sec_pg_sql_escape_literal "$db_name")"
  iddb="$(soviez_sec_pg_ident_quote "$db_name")"
  idowner="$(soviez_sec_pg_ident_quote "$app_user")"

  local exists
  exists="$(soviez_sec_pg_exec_admin "$container" "$admin_user" "$admin_pass" "$maintenance_db" \
    "SELECT 1 FROM pg_database WHERE datname='${qdb}'" | tr -d '[:space:]')"

  if [[ "$exists" != "1" ]]; then
    docker exec -e PGPASSWORD="$admin_pass" "$container" \
      psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$maintenance_db" \
      -c "CREATE DATABASE ${iddb} OWNER ${idowner};" >/dev/null
  else
    docker exec -e PGPASSWORD="$admin_pass" "$container" \
      psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$maintenance_db" \
      -c "ALTER DATABASE ${iddb} OWNER TO ${idowner};" >/dev/null 2>&1 || true
  fi

  docker exec -e PGPASSWORD="$admin_pass" "$container" \
    psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$db_name" \
    -c "GRANT CONNECT ON DATABASE ${iddb} TO ${idowner};" >/dev/null 2>&1 || true
  docker exec -e PGPASSWORD="$admin_pass" "$container" \
    psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$db_name" \
    -c "GRANT ALL ON SCHEMA public TO ${idowner};" >/dev/null 2>&1 || true
}

soviez_sec_pg_revoke_dangerous_memberships() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local database="${5:-postgres}"

  local iduser
  iduser="$(soviez_sec_pg_ident_quote "$app_user")"
  local role
  for role in pg_execute_server_program pg_read_server_files pg_write_server_files; do
    docker exec -e PGPASSWORD="$admin_pass" "$container" \
      psql -v ON_ERROR_STOP=0 -U "$admin_user" -d "$database" \
      -c "REVOKE ${role} FROM ${iduser};" >/dev/null 2>&1 || true
  done
  return 0
}

soviez_sec_pg_query_role_attrs() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local database="${5:-postgres}"

  local quser out
  quser="$(soviez_sec_pg_sql_escape_literal "$app_user")"
  out="$(soviez_sec_pg_exec_admin "$container" "$admin_user" "$admin_pass" "$database" \
    "SELECT rolsuper||','||rolcreaterole||','||rolcreatedb||','||rolreplication||','||rolbypassrls FROM pg_roles WHERE rolname='${quser}'" \
    | tr -d '[:space:]')"
  if [[ -z "$out" || "$out" != *,*,*,*,* ]]; then
    echo "UNKNOWN,UNKNOWN,UNKNOWN,UNKNOWN,UNKNOWN"
    return 1
  fi
  printf '%s\n' "$out"
}

soviez_sec_pg_query_dangerous_memberships() {
  local container="$1"
  local admin_user="$2"
  local admin_pass="$3"
  local app_user="$4"
  local database="${5:-postgres}"
  local quser
  quser="$(soviez_sec_pg_sql_escape_literal "$app_user")"
  soviez_sec_pg_exec_admin "$container" "$admin_user" "$admin_pass" "$database" \
    "SELECT COALESCE(string_agg(r.rolname, ','), '') FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid JOIN pg_roles u ON u.oid=m.member WHERE u.rolname='${quser}' AND r.rolname IN ('pg_execute_server_program','pg_read_server_files','pg_write_server_files')" \
    | tr -d '[:space:]'
}

soviez_sec_pg_assert_app_role_safe() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local database="${5:-postgres}"

  local attrs
  if ! attrs="$(soviez_sec_pg_query_role_attrs "$container" "$admin_user" "$admin_pass" "$app_user" "$database")"; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: cannot query role attrs for ${app_user}" >&2
    return 1
  fi
  local rolsuper rolcreaterole rolcreatedb rolreplication rolbypassrls
  IFS=',' read -r rolsuper rolcreaterole rolcreatedb rolreplication rolbypassrls <<<"$attrs"

  local bad=0
  case "$rolsuper" in
    t|true|TRUE|1|yes|YES) echo "[error] security:SEC_CRIT_PG_SUPERUSER: ${app_user} is SUPERUSER" >&2; bad=1 ;;
    UNKNOWN|unknown|'') echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: rolsuper unknown" >&2; bad=1 ;;
  esac
  case "$rolcreaterole" in
    t|true|TRUE|1|yes|YES) echo "[error] security:SEC_CRIT_PG_CREATEROLE: ${app_user} has CREATEROLE" >&2; bad=1 ;;
    UNKNOWN|unknown|'') echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: rolcreaterole unknown" >&2; bad=1 ;;
  esac
  case "$rolreplication" in
    t|true|TRUE|1|yes|YES) echo "[error] security:SEC_CRIT_PG_REPLICATION: ${app_user} has REPLICATION" >&2; bad=1 ;;
    UNKNOWN|unknown|'') echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: rolreplication unknown" >&2; bad=1 ;;
  esac
  case "$rolbypassrls" in
    t|true|TRUE|1|yes|YES) echo "[error] security:SEC_CRIT_PG_BYPASSRLS: ${app_user} has BYPASSRLS" >&2; bad=1 ;;
    UNKNOWN|unknown|'') echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: rolbypassrls unknown" >&2; bad=1 ;;
  esac

  local memberships
  memberships="$(soviez_sec_pg_query_dangerous_memberships "$container" "$admin_user" "$admin_pass" "$app_user" "$database" 2>/dev/null || echo UNKNOWN)"
  if [[ "$memberships" == "UNKNOWN" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: dangerous memberships query failed" >&2
    bad=1
  elif [[ -n "$memberships" ]]; then
    [[ "$memberships" == *pg_execute_server_program* ]] && echo "[error] security:SEC_CRIT_PG_EXECUTE_SERVER_PROGRAM: membership present" >&2 && bad=1
    [[ "$memberships" == *pg_read_server_files* ]] && echo "[error] security:SEC_CRIT_PG_READ_SERVER_FILES: membership present" >&2 && bad=1
    [[ "$memberships" == *pg_write_server_files* ]] && echo "[error] security:SEC_CRIT_PG_WRITE_SERVER_FILES: membership present" >&2 && bad=1
  fi

  [[ "$bad" -eq 0 ]]
}

soviez_sec_pg_prove_copy_program_denied() {
  local container="$1"
  local app_user="${2:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="$3"
  local database="${4:-postgres}"

  local out rc
  set +e
  out="$(docker exec -e PGPASSWORD="$app_pass" "$container"     psql -U "$app_user" -d "$database" -v ON_ERROR_STOP=1     -c "COPY (SELECT 1) TO PROGRAM 'true';" 2>&1)"
  rc=$?
  set +e
  if [[ $rc -eq 0 ]]; then
    echo "[error] security:SEC_CRIT_PG_EXECUTE_SERVER_PROGRAM: COPY PROGRAM succeeded for app role" >&2
    return 1
  fi
  return 0
}

soviez_sec_pg_prove_server_file_denied() {
  local container="$1"
  local app_user="${2:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="$3"
  local database="${4:-postgres}"
  local path="${5:-/tmp/soviez_sec_pg_probe_$$.csv}"

  local out rc
  set +e
  out="$(docker exec -e PGPASSWORD="$app_pass" "$container" \
    psql -U "$app_user" -d "$database" -v ON_ERROR_STOP=1 \
    -c "COPY (SELECT 1) TO '${path}';" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "[error] security:SEC_CRIT_PG_WRITE_SERVER_FILES: COPY TO server file succeeded for app role" >&2
    return 1
  fi

  set +e
  out="$(docker exec -e PGPASSWORD="$app_pass" "$container" \
    psql -U "$app_user" -d "$database" -v ON_ERROR_STOP=1 \
    -c "COPY tmp_soviez_sec_probe FROM '${path}';" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "[error] security:SEC_CRIT_PG_READ_SERVER_FILES: COPY FROM server file succeeded for app role" >&2
    return 1
  fi
  return 0
}

soviez_sec_pg_provision_least_privilege() {
  local container="$1"
  local admin_user="${2:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="$3"
  local app_user="${4:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="$5"
  local db_name="${6:-}"
  local maintenance_db="${7:-postgres}"

  [[ -n "$app_pass" ]] || app_pass="$(soviez_sec_pg_gen_password 32)"

  soviez_sec_pg_ensure_app_role "$container" "$admin_user" "$admin_pass" "$app_user" "$app_pass" "$maintenance_db" || return 1
  if [[ -n "$db_name" ]]; then
    soviez_sec_pg_ensure_database "$container" "$admin_user" "$admin_pass" "$app_user" "$db_name" "$maintenance_db" || return 1
  fi
  soviez_sec_pg_revoke_dangerous_memberships "$container" "$admin_user" "$admin_pass" "$app_user" "$maintenance_db" || return 1
  soviez_sec_pg_assert_app_role_safe "$container" "$admin_user" "$admin_pass" "$app_user" "$maintenance_db" || return 1
  if [[ -n "$app_pass" ]]; then
    local prove_db="${db_name:-$maintenance_db}"
    soviez_sec_pg_prove_copy_program_denied "$container" "$app_user" "$app_pass" "$prove_db" || return 1
    soviez_sec_pg_prove_server_file_denied "$container" "$app_user" "$app_pass" "$prove_db" || return 1
  fi
  return 0
}
