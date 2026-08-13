# shellcheck shell=bash
# Security Gate S1 — fail-closed critical containment gate.

soviez_sec__gate_add() {
  local key="$1" rstatus="$2" detail="${3:-}"
  if declare -F soviez_sec_report_add >/dev/null 2>&1; then
    soviez_sec_report_add "$key" "$rstatus" "$detail"
  else
    echo "[security] ${key}: ${rstatus} — ${detail}" >&2
  fi
}

soviez_sec__gate_check_bool() {
  # usage: soviez_sec__gate_check_bool KEY PASS_MSG FAIL_CODE FAIL_MSG cmd...
  local key="$1" pass_msg="$2" fail_code="$3" fail_msg="$4"
  shift 4
  local out rc
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    soviez_sec__gate_add "$key" PASS "$pass_msg"
    return 0
  fi
  if [[ "$out" == *SEC_CRIT_SECURITY_STATE_UNKNOWN* || "$out" == *UNKNOWN* ]]; then
    soviez_sec__gate_add "$key" UNKNOWN "${fail_msg}: ${out}"
  else
    soviez_sec__gate_add "$key" FAIL "${fail_code}: ${fail_msg}: ${out}"
  fi
  return 1
}

soviez_security_validate_critical_containment() {
  local mode="${SOVIEZ_SEC_MODE:-production}"
  local pg="${SOVIEZ_SEC_PG_CONTAINER:-}"
  local odoo="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local admin_user="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="${SOVIEZ_SEC_PG_ADMIN_PASS:-}"
  local app_user="${SOVIEZ_SEC_PG_APP_USER:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local app_pass="${SOVIEZ_SEC_PG_APP_PASS:-}"
  local conf="${SOVIEZ_SEC_ODOO_CONF:-}"
  local require_https="${SOVIEZ_SEC_REQUIRE_HTTPS:-0}"
  local domain="${SOVIEZ_SEC_DOMAIN:-}"
  local proxy_url="${SOVIEZ_SEC_PROXY_URL:-}"
  local report_dir="${SOVIEZ_SEC_REPORT_DIR:-}"

  case "$mode" in
    production|stage|update) ;;
    *)
      echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: invalid SOVIEZ_SEC_MODE=${mode}" >&2
      return 1
      ;;
  esac

  if declare -F soviez_sec_report_init >/dev/null 2>&1; then
    soviez_sec_report_init "$report_dir"
  fi

  local overall_rc=0

  # --- PG role attrs ---
  if [[ -n "$pg" && -n "$admin_pass" ]] && docker inspect "$pg" >/dev/null 2>&1; then
    local attrs
    if attrs="$(soviez_sec_pg_query_role_attrs "$pg" "$admin_user" "$admin_pass" "$app_user" postgres 2>/dev/null)"; then
      local rolsuper rolcreaterole rolcreatedb rolreplication rolbypassrls
      IFS=',' read -r rolsuper rolcreaterole rolcreatedb rolreplication rolbypassrls <<<"$attrs"
      case "$rolsuper" in
        f|false|FALSE|0|no|NO) soviez_sec__gate_add PG_APP_NOT_SUPERUSER PASS "rolsuper=f" ;;
        t|true|TRUE|1) soviez_sec__gate_add PG_APP_NOT_SUPERUSER FAIL "SEC_CRIT_PG_SUPERUSER"; overall_rc=1 ;;
        *) soviez_sec__gate_add PG_APP_NOT_SUPERUSER UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN rolsuper=${rolsuper}"; overall_rc=1 ;;
      esac
      case "$rolcreaterole" in
        f|false|FALSE|0|no|NO) soviez_sec__gate_add NO_CREATEROLE PASS "rolcreaterole=f" ;;
        t|true|TRUE|1) soviez_sec__gate_add NO_CREATEROLE FAIL "SEC_CRIT_PG_CREATEROLE"; overall_rc=1 ;;
        *) soviez_sec__gate_add NO_CREATEROLE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"; overall_rc=1 ;;
      esac
      case "$rolreplication" in
        f|false|FALSE|0|no|NO) soviez_sec__gate_add NO_REPLICATION PASS "rolreplication=f" ;;
        t|true|TRUE|1) soviez_sec__gate_add NO_REPLICATION FAIL "SEC_CRIT_PG_REPLICATION"; overall_rc=1 ;;
        *) soviez_sec__gate_add NO_REPLICATION UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"; overall_rc=1 ;;
      esac
      case "$rolbypassrls" in
        f|false|FALSE|0|no|NO) soviez_sec__gate_add NO_BYPASSRLS PASS "rolbypassrls=f" ;;
        t|true|TRUE|1) soviez_sec__gate_add NO_BYPASSRLS FAIL "SEC_CRIT_PG_BYPASSRLS"; overall_rc=1 ;;
        *) soviez_sec__gate_add NO_BYPASSRLS UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"; overall_rc=1 ;;
      esac
    else
      soviez_sec__gate_add PG_APP_NOT_SUPERUSER UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN cannot query"
      soviez_sec__gate_add NO_CREATEROLE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      soviez_sec__gate_add NO_REPLICATION UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      soviez_sec__gate_add NO_BYPASSRLS UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      overall_rc=1
    fi

    local memberships
    memberships="$(soviez_sec_pg_query_dangerous_memberships "$pg" "$admin_user" "$admin_pass" "$app_user" postgres 2>/dev/null || echo UNKNOWN)"
    if [[ "$memberships" == "UNKNOWN" ]]; then
      soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      overall_rc=1
    elif [[ -z "$memberships" ]]; then
      soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS PASS "none"
    else
      [[ "$memberships" == *pg_execute_server_program* ]] && soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS FAIL "SEC_CRIT_PG_EXECUTE_SERVER_PROGRAM" && overall_rc=1
      [[ "$memberships" == *pg_read_server_files* ]] && soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS FAIL "SEC_CRIT_PG_READ_SERVER_FILES" && overall_rc=1
      [[ "$memberships" == *pg_write_server_files* ]] && soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS FAIL "SEC_CRIT_PG_WRITE_SERVER_FILES" && overall_rc=1
      if [[ "$memberships" != *pg_* ]]; then
        soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS FAIL "unexpected memberships"
        overall_rc=1
      fi
    fi
  else
    soviez_sec__gate_add PG_APP_NOT_SUPERUSER UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN pg/admin unavailable"
    soviez_sec__gate_add NO_CREATEROLE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    soviez_sec__gate_add NO_REPLICATION UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    soviez_sec__gate_add NO_BYPASSRLS UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    soviez_sec__gate_add NO_DANGEROUS_MEMBERSHIPS UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    overall_rc=1
  fi

  # --- PG public port ---
  if [[ -n "$pg" ]] && docker inspect "$pg" >/dev/null 2>&1; then
    if soviez_sec_pg_assert_no_public_publish "$pg" 2>/dev/null; then
      soviez_sec__gate_add PG_PUBLIC_PORT_ABSENT PASS "no public 5432"
    else
      soviez_sec__gate_add PG_PUBLIC_PORT_ABSENT FAIL "SEC_CRIT_PG_PUBLIC_PORT"
      overall_rc=1
    fi
  else
    soviez_sec__gate_add PG_PUBLIC_PORT_ABSENT UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    overall_rc=1
  fi

  # --- Odoo public ports ---
  if [[ -n "$odoo" ]] && docker inspect "$odoo" >/dev/null 2>&1; then
    if soviez_sec_odoo_assert_no_public_direct_ports "$odoo" 2>/dev/null; then
      soviez_sec__gate_add ODOO_DIRECT_PUBLIC_PORT_ABSENT PASS "no public 8069/8071/8072"
    else
      soviez_sec__gate_add ODOO_DIRECT_PUBLIC_PORT_ABSENT FAIL "SEC_CRIT_ODOO_PUBLIC_PORT"
      overall_rc=1
    fi
  else
    soviez_sec__gate_add ODOO_DIRECT_PUBLIC_PORT_ABSENT UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    overall_rc=1
  fi

  # --- Docker baselines ---
  if [[ -n "$odoo" ]] && docker inspect "$odoo" >/dev/null 2>&1; then
    if soviez_sec_docker_assert_container_baseline "$odoo" odoo 2>/dev/null; then
      soviez_sec__gate_add ODOO_PRIVILEGED_FALSE PASS "baseline ok"
      soviez_sec__gate_add DOCKER_SOCKET_NOT_MOUNTED PASS "odoo"
      soviez_sec__gate_add HOST_NETWORK_NOT_USED PASS "odoo"
    else
      local priv sock hostn
      priv="$(docker inspect -f '{{.HostConfig.Privileged}}' "$odoo" 2>/dev/null || echo UNKNOWN)"
      hostn="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$odoo" 2>/dev/null || echo UNKNOWN)"
      if [[ "$priv" == "true" ]]; then
        soviez_sec__gate_add ODOO_PRIVILEGED_FALSE FAIL "SEC_CRIT_PRIVILEGED_CONTAINER"
      elif [[ "$priv" == "UNKNOWN" ]]; then
        soviez_sec__gate_add ODOO_PRIVILEGED_FALSE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      else
        soviez_sec__gate_add ODOO_PRIVILEGED_FALSE PASS "Privileged=false"
      fi
      if soviez_sec_docker_mounts_include_docker_sock "$odoo" 2>/dev/null; then
        soviez_sec__gate_add DOCKER_SOCKET_NOT_MOUNTED FAIL "SEC_CRIT_DOCKER_SOCKET"
      else
        soviez_sec__gate_add DOCKER_SOCKET_NOT_MOUNTED PASS "odoo"
      fi
      if [[ "$hostn" == "host" ]]; then
        soviez_sec__gate_add HOST_NETWORK_NOT_USED FAIL "SEC_CRIT_HOST_NETWORK"
      elif [[ "$hostn" == "UNKNOWN" ]]; then
        soviez_sec__gate_add HOST_NETWORK_NOT_USED UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      else
        soviez_sec__gate_add HOST_NETWORK_NOT_USED PASS "odoo"
      fi
      overall_rc=1
    fi
  else
    soviez_sec__gate_add ODOO_PRIVILEGED_FALSE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    soviez_sec__gate_add DOCKER_SOCKET_NOT_MOUNTED UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    soviez_sec__gate_add HOST_NETWORK_NOT_USED UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    overall_rc=1
  fi

  if [[ -n "$pg" ]] && docker inspect "$pg" >/dev/null 2>&1; then
    if soviez_sec_docker_assert_container_baseline "$pg" postgres 2>/dev/null; then
      soviez_sec__gate_add POSTGRES_PRIVILEGED_FALSE PASS "baseline ok"
    else
      local ppriv
      ppriv="$(docker inspect -f '{{.HostConfig.Privileged}}' "$pg" 2>/dev/null || echo UNKNOWN)"
      if [[ "$ppriv" == "true" ]]; then
        soviez_sec__gate_add POSTGRES_PRIVILEGED_FALSE FAIL "SEC_CRIT_PRIVILEGED_CONTAINER"
      elif [[ "$ppriv" == "UNKNOWN" ]]; then
        soviez_sec__gate_add POSTGRES_PRIVILEGED_FALSE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      else
        soviez_sec__gate_add POSTGRES_PRIVILEGED_FALSE FAIL "postgres baseline failed"
      fi
      if soviez_sec_docker_mounts_include_docker_sock "$pg" 2>/dev/null; then
        soviez_sec__gate_add DOCKER_SOCKET_NOT_MOUNTED FAIL "SEC_CRIT_DOCKER_SOCKET postgres"
      fi
      overall_rc=1
    fi
  else
    soviez_sec__gate_add POSTGRES_PRIVILEGED_FALSE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
    overall_rc=1
  fi

  # --- Odoo conf defaults ---
  if [[ -n "$conf" && -f "$conf" ]]; then
    if soviez_sec_odoo_conf_assert_production_defaults "$conf" 2>/dev/null; then
      soviez_sec__gate_add ODOO_PROXY_MODE_TRUE PASS "proxy_mode=True"
      soviez_sec__gate_add ODOO_LIST_DB_FALSE PASS "list_db=False"
    else
      local proxy list_db
      proxy="$(soviez_sec_odoo_conf_get_option "$conf" proxy_mode 2>/dev/null || echo unset)"
      list_db="$(soviez_sec_odoo_conf_get_option "$conf" list_db 2>/dev/null || echo unset)"
      case "$(printf '%s' "$proxy" | tr '[:upper:]' '[:lower:]')" in
        true|1|yes) soviez_sec__gate_add ODOO_PROXY_MODE_TRUE PASS ;;
        *) soviez_sec__gate_add ODOO_PROXY_MODE_TRUE FAIL "SEC_CRIT_PROXY_MODE_DISABLED proxy_mode=${proxy}"; overall_rc=1 ;;
      esac
      case "$(printf '%s' "$list_db" | tr '[:upper:]' '[:lower:]')" in
        false|0|no) soviez_sec__gate_add ODOO_LIST_DB_FALSE PASS ;;
        *) soviez_sec__gate_add ODOO_LIST_DB_FALSE FAIL "SEC_CRIT_LIST_DB_ENABLED list_db=${list_db}"; overall_rc=1 ;;
      esac
    fi
  else
    soviez_sec__gate_add ODOO_PROXY_MODE_TRUE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN conf missing"
    soviez_sec__gate_add ODOO_LIST_DB_FALSE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN conf missing"
    overall_rc=1
  fi

  # --- Weak credentials (env) ---
  local weak_hit=0
  local candidate
  for candidate in \
    "${SOVIEZ_APP_PASSWORD:-}" \
    "${SOVIEZ_ADMIN_PASSWORD:-}" \
    "${SOVIEZ_SEC_PG_APP_PASS:-}" \
    "${admin_pass}"; do
    [[ -n "$candidate" ]] || continue
    if declare -F soviez_sec_password_is_weak >/dev/null 2>&1 && soviez_sec_password_is_weak "$candidate"; then
      weak_hit=1
    fi
  done
  if [[ "$weak_hit" -eq 1 ]]; then
    soviez_sec__gate_add WEAK_DEFAULT_CREDENTIALS_ABSENT FAIL "SEC_CRIT_WEAK_ADMIN_CREDENTIAL"
    overall_rc=1
  else
    soviez_sec__gate_add WEAK_DEFAULT_CREDENTIALS_ABSENT PASS "no weak env credentials detected"
  fi

  # Bootstrap secret must not appear as Odoo env (best-effort inspect).
  if [[ -n "$odoo" && -n "$admin_pass" ]] && docker inspect "$odoo" >/dev/null 2>&1; then
    local env_blob
    env_blob="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$odoo" 2>/dev/null || true)"
    if [[ -n "$env_blob" && -n "$admin_pass" ]] && printf '%s' "$env_blob" | grep -Fq -- "$admin_pass"; then
      soviez_sec__gate_add BOOTSTRAP_SECRET_NOT_IN_ODOO FAIL "SEC_CRIT_BOOTSTRAP_SECRET_IN_ODOO"
      overall_rc=1
    else
      soviez_sec__gate_add BOOTSTRAP_SECRET_NOT_IN_ODOO PASS "bootstrap secret not found in odoo env"
    fi
  else
    soviez_sec__gate_add BOOTSTRAP_SECRET_NOT_IN_ODOO SKIP "odoo/admin unavailable"
  fi

  # --- Optional DB reachability (prefer app DB; fall back to postgres) ---
  if [[ -n "$pg" && -n "$app_user" && -n "$app_pass" ]] && docker inspect "$pg" >/dev/null 2>&1; then
    local reach_db="${SOVIEZ_SEC_PG_DB:-postgres}"
    if docker exec -e PGPASSWORD="$app_pass" "$pg" \
      psql -U "$app_user" -d "$reach_db" -tAc 'SELECT 1' >/dev/null 2>&1 \
      || docker exec -e PGPASSWORD="$app_pass" "$pg" \
        psql -U "$app_user" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
      soviez_sec__gate_add ODOO_DB_REACHABLE PASS "app role connected"
    else
      soviez_sec__gate_add ODOO_DB_REACHABLE FAIL "SEC_HIGH_INTERNAL_DB_UNREACHABLE"
      # HIGH — still fail-closed for gate overall when containers claimed up
      overall_rc=1
    fi
  else
    soviez_sec__gate_add ODOO_DB_REACHABLE SKIP "optional; credentials/containers not fully provided"
  fi

  # --- Reverse proxy / HTTPS ---
  if [[ "$mode" == "production" && "$require_https" == "1" ]]; then
    local url="${proxy_url}"
    if [[ -z "$url" && -n "$domain" ]]; then
      url="https://${domain}/"
    fi
    if [[ -z "$url" ]]; then
      soviez_sec__gate_add REVERSE_PROXY_REACHABLE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN no proxy url/domain"
      soviez_sec__gate_add HTTPS_REQUIRED UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
      overall_rc=1
    else
      local curl_rc=1
      if command -v curl >/dev/null 2>&1; then
        set +e
        curl -fsS --max-time 10 "$url" >/dev/null 2>&1
        curl_rc=$?
        set -e
      elif command -v wget >/dev/null 2>&1; then
        set +e
        wget -q -O /dev/null --timeout=10 "$url" >/dev/null 2>&1
        curl_rc=$?
        set -e
      else
        soviez_sec__gate_add REVERSE_PROXY_REACHABLE UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN no curl/wget"
        soviez_sec__gate_add HTTPS_REQUIRED UNKNOWN "SEC_CRIT_SECURITY_STATE_UNKNOWN"
        overall_rc=1
        curl_rc=2
      fi
      if [[ $curl_rc -eq 0 ]]; then
        soviez_sec__gate_add REVERSE_PROXY_REACHABLE PASS "$url"
        case "$url" in
          https://*) soviez_sec__gate_add HTTPS_REQUIRED PASS ;;
          *) soviez_sec__gate_add HTTPS_REQUIRED FAIL "SEC_HIGH_REVERSE_PROXY_UNREACHABLE non-https url"; overall_rc=1 ;;
        esac
      elif [[ $curl_rc -ne 2 ]]; then
        soviez_sec__gate_add REVERSE_PROXY_REACHABLE FAIL "SEC_HIGH_REVERSE_PROXY_UNREACHABLE"
        soviez_sec__gate_add HTTPS_REQUIRED FAIL "SEC_HIGH_REVERSE_PROXY_UNREACHABLE"
        overall_rc=1
      fi
    fi
  else
    soviez_sec__gate_add REVERSE_PROXY_REACHABLE SKIP "not required for mode=${mode} https=${require_https}"
    soviez_sec__gate_add HTTPS_REQUIRED SKIP "not required"
  fi

  local final="FAIL"
  if declare -F soviez_sec_report_finalize >/dev/null 2>&1; then
    if final="$(soviez_sec_report_finalize)"; then
      :
    else
      final="FAIL"
      overall_rc=1
    fi
  else
    [[ "$overall_rc" -eq 0 ]] && final="PASS"
  fi

  if [[ "$final" == "PASS" && "$overall_rc" -eq 0 ]]; then
    echo "[security] SEC_OK_CRITICAL_CONTAINMENT"
    return 0
  fi
  return 1
}

soviez_security_gate_require_pass() {
  if soviez_security_validate_critical_containment "$@"; then
    return 0
  fi
  if declare -F soviez_security_die >/dev/null 2>&1; then
    soviez_security_die SEC_CRIT_SECURITY_STATE_UNKNOWN "critical containment gate failed (fail-closed)"
  fi
  echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: critical containment gate failed (fail-closed)" >&2
  return 1
}
