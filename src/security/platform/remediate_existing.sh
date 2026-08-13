# shellcheck shell=bash
# Security Gate S1 — remediate existing app roles (never re-grant SUPERUSER on failure).

soviez_sec_remediate_existing_app_role() {
  local container="${1:-${SOVIEZ_SEC_PG_CONTAINER:-}}"
  local admin_user="${2:-${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}}"
  local admin_pass="${3:-${SOVIEZ_SEC_PG_ADMIN_PASS:-}}"
  local app_user="${4:-${SOVIEZ_SEC_PG_APP_USER:-${SOVIEZ_PG_APP_USER:-soviez_app}}}"
  local database="${5:-postgres}"

  [[ -n "$container" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: pg container required" >&2; return 1; }
  [[ -n "$admin_pass" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: admin pass required for remediation" >&2; return 1; }

  local snap=""
  if declare -F soviez_sec_rollback_snapshot_dir >/dev/null 2>&1; then
    snap="$(soviez_sec_rollback_snapshot_dir)" || true
  fi

  local iduser
  iduser="$(soviez_sec_pg_ident_quote "$app_user")"

  # Strip dangerous attributes. On any failure: do NOT grant SUPERUSER back.
  if ! docker exec -e PGPASSWORD="$admin_pass" "$container" \
    psql -v ON_ERROR_STOP=1 -U "$admin_user" -d "$database" \
    -c "ALTER ROLE ${iduser} NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;" >/dev/null; then
    echo "[error] security:SEC_CRIT_PG_SUPERUSER: ALTER ROLE strip failed for ${app_user} (no privilege re-grant)" >&2
    return 1
  fi

  if declare -F soviez_sec_pg_revoke_dangerous_memberships >/dev/null 2>&1; then
    soviez_sec_pg_revoke_dangerous_memberships "$container" "$admin_user" "$admin_pass" "$app_user" "$database" || true
  fi

  if declare -F soviez_sec_pg_assert_app_role_safe >/dev/null 2>&1; then
    if ! soviez_sec_pg_assert_app_role_safe "$container" "$admin_user" "$admin_pass" "$app_user" "$database"; then
      echo "[error] security:SEC_CRIT_PG_SUPERUSER: post-remediation assert failed (no SUPERUSER re-grant); snap=${snap:-none}" >&2
      return 1
    fi
  fi
  return 0
}
