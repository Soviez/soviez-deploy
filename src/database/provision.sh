# shellcheck shell=bash

soviez_database_provision() {
  local op_id="$1"
  local db_name="soviez_${op_id//-/_}"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local marker="$SOVIEZ_ROOT/stubs/db-${op_id}.ready"
    mkdir -p "$SOVIEZ_ROOT/stubs"
    printf 'db=%s\n' "$db_name" > "$marker"
    soviez_tenant_secret_write "db_name" "$db_name"
    # Deterministic non-weak test secrets (still subject to policy when gated).
    local app_pass admin_pass
    app_pass="$(soviez_sec_pg_gen_password 24 2>/dev/null || python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(24)))')"
    admin_pass="$(soviez_sec_pg_gen_password 24 2>/dev/null || python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(24)))')"
    if declare -F soviez_sec_password_assert_not_weak >/dev/null 2>&1; then
      soviez_sec_password_assert_not_weak "$app_pass" "db_password" || return 1
      soviez_sec_password_assert_not_weak "$admin_pass" "pg_admin_password" || return 1
    fi
    soviez_tenant_secret_write "db_password" "$app_pass"
    soviez_tenant_secret_write "pg_admin_password" "$admin_pass"
    printf '%s' "$db_name"
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: docker required for database provision" >&2
    return 1
  fi

  local net="${SOVIEZ_DB_NETWORK:-soviez-net-${op_id}}"
  local pg_name="${SOVIEZ_DB_CONTAINER:-soviez-db-${op_id}}"
  local admin_user="${SOVIEZ_PG_ADMIN_USER:-soviez_admin}"
  local app_user="${SOVIEZ_PG_APP_USER:-soviez_app}"
  local admin_pass app_pass

  if admin_pass="$(soviez_tenant_secret_read pg_admin_password 2>/dev/null)"; then
    :
  else
    admin_pass="$(soviez_sec_pg_gen_password 32)"
    soviez_tenant_secret_write "pg_admin_password" "$admin_pass"
  fi
  if app_pass="$(soviez_tenant_secret_read db_password 2>/dev/null)"; then
    :
  else
    app_pass="$(soviez_sec_pg_gen_password 32)"
    soviez_tenant_secret_write "db_password" "$app_pass"
  fi
  soviez_tenant_secret_write "db_name" "$db_name"

  if declare -F soviez_sec_password_assert_not_weak >/dev/null 2>&1; then
    soviez_sec_password_assert_not_weak "$app_pass" "db_password" || return 1
    soviez_sec_password_assert_not_weak "$admin_pass" "pg_admin_password" || return 1
  fi

  docker network create "$net" >/dev/null 2>&1 || true

  if ! docker inspect "$pg_name" >/dev/null 2>&1; then
    docker run -d --name "$pg_name" --network "$net" --restart unless-stopped \
      -e POSTGRES_USER="$admin_user" \
      -e POSTGRES_PASSWORD="$admin_pass" \
      -e POSTGRES_DB=postgres \
      "${SOVIEZ_DB_IMAGE:-postgres:16}" >/dev/null || return 1
  else
    docker start "$pg_name" >/dev/null 2>&1 || true
    docker network connect "$net" "$pg_name" >/dev/null 2>&1 || true
  fi

  local i
  for i in $(seq 1 60); do
    docker exec "$pg_name" pg_isready -U "$admin_user" -d postgres >/dev/null 2>&1 && break
    sleep 1
  done
  docker exec "$pg_name" pg_isready -U "$admin_user" -d postgres >/dev/null 2>&1 || return 1

  if declare -F soviez_sec_pg_provision_least_privilege >/dev/null 2>&1; then
    soviez_sec_pg_provision_least_privilege "$pg_name" "$admin_user" "$admin_pass" \
      "$app_user" "$app_pass" "$db_name" || return 1
  else
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: platform pg provision missing" >&2
    return 1
  fi

  # Dry-form / markers for gate evidence (no secrets).
  mkdir -p "${SOVIEZ_ROOT:-/tmp}/security"
  printf 'pg=%s\ndb=%s\napp_user=%s\nmode=provisioned\n' "$pg_name" "$db_name" "$app_user" \
    > "${SOVIEZ_ROOT:-/tmp}/security/db-provision-${op_id}.marker"
  chmod 600 "${SOVIEZ_ROOT:-/tmp}/security/db-provision-${op_id}.marker" 2>/dev/null || true

  if [[ "${SOVIEZ_SEC_RUN_GATE_ON_PROVISION:-0}" == "1" ]]; then
    export SOVIEZ_SEC_MODE="${SOVIEZ_SEC_MODE:-production}"
    export SOVIEZ_SEC_PG_CONTAINER="$pg_name"
    export SOVIEZ_SEC_PG_ADMIN_USER="$admin_user"
    export SOVIEZ_SEC_PG_ADMIN_PASS="$admin_pass"
    export SOVIEZ_SEC_PG_APP_USER="$app_user"
    export SOVIEZ_SEC_PG_APP_PASS="$app_pass"
    if declare -F soviez_security_validate_critical_containment >/dev/null 2>&1; then
      # Odoo may not exist yet — gate may UNKNOWN some checks; record dry run only when odoo present
      if [[ -n "${SOVIEZ_SEC_ODOO_CONTAINER:-}" ]] && docker inspect "${SOVIEZ_SEC_ODOO_CONTAINER}" >/dev/null 2>&1; then
        soviez_security_validate_critical_containment || return 1
      fi
    fi
  fi

  soviez_log_info "Provisioning database $db_name"
  printf '%s' "$db_name"
}
