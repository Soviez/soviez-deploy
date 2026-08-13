# shellcheck shell=bash
# Security Gate S1+S2 — CLI commands.

soviez_cmd_security_check() {
  local env_file="${SOVIEZ_CLI_ENV_FILE:-${ENV_FILE:-}}"
  if [[ -n "$env_file" && -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
  export SOVIEZ_SEC_MODE="${SOVIEZ_SEC_MODE:-production}"
  export SOVIEZ_SEC_PG_CONTAINER="${SOVIEZ_SEC_PG_CONTAINER:-${SOVIEZ_DB_CONTAINER:-${DB_CONTAINER:-}}}"
  export SOVIEZ_SEC_ODOO_CONTAINER="${SOVIEZ_SEC_ODOO_CONTAINER:-${SOVIEZ_WEB_CONTAINER:-${WEB_CONTAINER:-}}}"
  export SOVIEZ_SEC_PG_ADMIN_USER="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  export SOVIEZ_SEC_PG_APP_USER="${SOVIEZ_SEC_PG_APP_USER:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  export SOVIEZ_SEC_PG_ADMIN_PASS="${SOVIEZ_SEC_PG_ADMIN_PASS:-${SOVIEZ_PG_ADMIN_PASSWORD:-}}"
  export SOVIEZ_SEC_PG_APP_PASS="${SOVIEZ_SEC_PG_APP_PASS:-${SOVIEZ_DB_PASSWORD:-}}"
  export SOVIEZ_SEC_ODOO_CONF="${SOVIEZ_SEC_ODOO_CONF:-}"
  export SOVIEZ_SEC_REPORT_DIR="${SOVIEZ_SEC_REPORT_DIR:-${SOVIEZ_ROOT:-.}/security/reports}"
  local rc=0
  soviez_security_validate_critical_containment || rc=1
  if declare -F soviez_security_validate_host_edge >/dev/null 2>&1; then
    # Separate report dir for S2 to avoid clobbering S1 entries mid-flight
    local s2dir="${SOVIEZ_SEC_REPORT_DIR}/s2"
    SOVIEZ_SEC_REPORT_DIR="$s2dir" soviez_security_validate_host_edge || rc=1
  fi
  return "$rc"
}

soviez_cmd_security_harden() {
  local pg="${SOVIEZ_SEC_PG_CONTAINER:-${SOVIEZ_DB_CONTAINER:-}}"
  local admin_user="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="${SOVIEZ_SEC_PG_ADMIN_PASS:-${SOVIEZ_PG_ADMIN_PASSWORD:-}}"
  local app_user="${SOVIEZ_SEC_PG_APP_USER:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="${SOVIEZ_SEC_PG_APP_PASS:-${SOVIEZ_DB_PASSWORD:-}}"
  if [[ -n "$pg" && -n "$admin_pass" && -n "$app_pass" ]]; then
    if declare -F soviez_sec_remediate_existing_app_role >/dev/null 2>&1; then
      soviez_sec_remediate_existing_app_role "$pg" "$admin_user" "$admin_pass" "$app_user" "$app_pass" || return 1
    elif declare -F soviez_sec_pg_provision_least_privilege >/dev/null 2>&1; then
      local dbn="${SOVIEZ_DB_NAME:-postgres}"
      soviez_sec_pg_provision_least_privilege "$pg" "$admin_user" "$admin_pass" "$app_user" "$app_pass" "$dbn" || return 1
    fi
  fi
  if declare -F soviez_sec_s2_harden >/dev/null 2>&1; then
    soviez_sec_s2_harden || true
  fi
  soviez_cmd_security_check
}

soviez_cmd_security_report() {
  local dir="${SOVIEZ_SEC_REPORT_DIR:-${SOVIEZ_ROOT:-.}/security/reports}"
  # Prefer latest S3 human report if present
  local latest
  latest="$(ls -1t "${SOVIEZ_SEC_S3_LAST_EVIDENCE:-}/report.txt" "$dir"/s3/*/report.txt "$dir"/report.txt "$dir"/*/report.txt "$dir"/critical_containment_*.txt 2>/dev/null | head -1 || true)"
  if [[ -z "$latest" || ! -f "$latest" ]]; then
    echo "No security report found under $dir" >&2
    return 1
  fi
  cat "$latest"
}
