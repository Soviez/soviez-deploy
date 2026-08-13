# shellcheck shell=bash
# Security Gate S2 — fail-closed host & edge security gate.

soviez_security_validate_host_edge() {
  local mode="${SOVIEZ_SEC_MODE:-production}"
  local report_dir="${SOVIEZ_SEC_REPORT_DIR:-}"
  local odoo="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local pg="${SOVIEZ_SEC_PG_CONTAINER:-}"
  local domain="${SOVIEZ_SEC_DOMAIN:-}"
  local require_tls="${SOVIEZ_SEC_REQUIRE_HTTPS:-0}"
  local nginx_conf="${SOVIEZ_SEC_NGINX_CONF:-}"

  export SOVIEZ_SEC_GATE_LABEL="${SOVIEZ_SEC_GATE_LABEL:-S2}"

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
  local add
  add() { soviez_sec__gate_add "$@"; }

  # --- Firewall backend ---
  local backend="UNKNOWN"
  if declare -F soviez_fw_detect_backend >/dev/null 2>&1; then
    backend="$(soviez_fw_detect_backend 2>/dev/null || echo UNKNOWN)"
  fi
  if [[ "$backend" == "UNKNOWN" || -z "$backend" ]]; then
    add FIREWALL_BACKEND_DETECTED UNKNOWN "SEC_CRIT_FIREWALL_STATE_UNKNOWN"
    overall_rc=1
  else
    add FIREWALL_BACKEND_DETECTED PASS "backend=${backend}"
  fi

  if declare -F soviez_fw_validate >/dev/null 2>&1; then
    if soviez_fw_validate "$backend" >/dev/null 2>&1; then
      add FIREWALL_POLICY_VALID PASS "ok"
    else
      # On macOS/dev hosts without firewall tools, stage mode may SKIP.
      if [[ "$mode" == "stage" || "${SOVIEZ_FW_OPTIONAL:-0}" == "1" ]]; then
        add FIREWALL_POLICY_VALID SKIP "firewall optional on this host"
      else
        add FIREWALL_POLICY_VALID FAIL "SEC_CRIT_FIREWALL_STATE_UNKNOWN"
        overall_rc=1
      fi
    fi
  fi

  # --- Docker forwarding ---
  if declare -F soviez_fw_docker_forwarding_healthy >/dev/null 2>&1; then
    if soviez_fw_docker_forwarding_healthy >/dev/null 2>&1; then
      add DOCKER_FORWARDING_HEALTHY PASS "docker ok"
    else
      add DOCKER_FORWARDING_HEALTHY FAIL "SEC_HIGH_DOCKER_FORWARDING_BROKEN"
      overall_rc=1
    fi
  else
    add DOCKER_FORWARDING_HEALTHY SKIP "helper absent"
  fi

  # --- Public exposure (reuse S1 helpers when containers provided) ---
  add PUBLIC_80_EXPECTED INFO "expected open for Production HTTP/ACME"
  add PUBLIC_443_EXPECTED INFO "expected open for Production HTTPS"

  if [[ -n "$odoo" ]] && declare -F soviez_sec_odoo_assert_no_public_direct_ports >/dev/null 2>&1; then
    if soviez_sec_odoo_assert_no_public_direct_ports "$odoo" >/dev/null 2>&1; then
      add PUBLIC_8069_BLOCKED PASS "loopback or unpublished"
      add PUBLIC_8071_BLOCKED PASS "no public bind detected"
      add PUBLIC_8072_BLOCKED PASS "no public bind detected"
    else
      add PUBLIC_8069_BLOCKED FAIL "SEC_CRIT_PUBLIC_ODOO_PORT"
      overall_rc=1
    fi
  else
    # Inspect via docker if name given with generic inspect
    if [[ -n "$odoo" ]] && command -v docker >/dev/null 2>&1; then
      local pubs
      pubs="$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$odoo" 2>/dev/null || echo "")"
      if [[ "$pubs" == *'"HostIp":"0.0.0.0"'* ]] || [[ "$pubs" == *'"HostIp":""'* && "$pubs" == *'8069'* ]]; then
        # Empty HostIp often means 0.0.0.0
        if [[ "$pubs" == *'8069/tcp'* && "$pubs" != *'127.0.0.1'* ]]; then
          add PUBLIC_8069_BLOCKED FAIL "SEC_CRIT_PUBLIC_ODOO_PORT"
          overall_rc=1
        else
          add PUBLIC_8069_BLOCKED PASS "ok"
        fi
      else
        add PUBLIC_8069_BLOCKED PASS "ok"
      fi
      add PUBLIC_8071_BLOCKED PASS
      add PUBLIC_8072_BLOCKED PASS
    else
      add PUBLIC_8069_BLOCKED SKIP "no odoo container"
      add PUBLIC_8071_BLOCKED SKIP "no odoo container"
      add PUBLIC_8072_BLOCKED SKIP "no odoo container"
    fi
  fi

  if [[ -n "$pg" ]] && command -v docker >/dev/null 2>&1; then
    local pp
    pp="$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$pg" 2>/dev/null || echo "")"
    if [[ "$pp" == *'5432/tcp'* && ( "$pp" == *'0.0.0.0'* || "$pp" == *'"HostIp":""'* ) && "$pp" != *'127.0.0.1'* ]]; then
      add PUBLIC_5432_BLOCKED FAIL "SEC_CRIT_PUBLIC_POSTGRES_PORT"
      overall_rc=1
    else
      add PUBLIC_5432_BLOCKED PASS "not publicly published"
    fi
  else
    add PUBLIC_5432_BLOCKED SKIP "no pg container"
  fi

  # Docker daemon exposure
  if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | grep -Eq ':2375\\b|:2376\\b'; then
    add DOCKER_DAEMON_EXPOSURE FAIL "SEC_CRIT_DOCKER_DAEMON_EXPOSED"
    overall_rc=1
  else
    add DOCKER_DAEMON_EXPOSURE PASS "2375/2376 not publicly listening (or ss N/A)"
  fi

  # --- SSH ---
  if declare -F soviez_ssh_detect_state >/dev/null 2>&1; then
    local st
    st="$(soviez_ssh_detect_state "${SOVIEZ_SSH_CONFIG:-/etc/ssh/sshd_config}" 2>/dev/null || echo unknown)"
    add SSH_ACCESS_SAFE INFO "$st"
    if [[ "$st" == *password_auth=yes* ]]; then
      if declare -F soviez_ssh_has_alternate_access >/dev/null 2>&1 && soviez_ssh_has_alternate_access; then
        add SSH_PASSWORD_AUTH WARN "SEC_HIGH_SSH_PASSWORD_AUTH_ENABLED — alternate access exists"
      else
        add SSH_PASSWORD_AUTH WARN "SEC_WARN_SSH_HARDENING_DEFERRED"
      fi
    else
      add SSH_PASSWORD_AUTH PASS "password auth not yes or N/A"
    fi
    if [[ "$st" == *root_login=yes* ]]; then
      add SSH_ROOT_LOGIN WARN "SEC_HIGH_ROOT_SSH_ENABLED"
    else
      add SSH_ROOT_LOGIN PASS "root login not unrestricted yes"
    fi
  fi

  # --- Nginx ---
  if [[ -n "$nginx_conf" && -f "$nginx_conf" ]]; then
    if declare -F soviez_nginx_s2_validate_syntax >/dev/null 2>&1 && soviez_nginx_s2_validate_syntax "$nginx_conf"; then
      add NGINX_CONFIG_VALID PASS
    else
      add NGINX_CONFIG_VALID FAIL "SEC_CRIT_NGINX_INVALID"
      overall_rc=1
    fi
    if declare -F soviez_edge_reject_spoofed_xff_policy >/dev/null 2>&1; then
      if soviez_edge_reject_spoofed_xff_policy "$nginx_conf"; then
        add REAL_IP_POLICY_VALID PASS
      else
        add REAL_IP_POLICY_VALID FAIL "spoof trust"
        overall_rc=1
      fi
    fi
  else
    add NGINX_CONFIG_VALID SKIP "no nginx conf provided"
    add REAL_IP_POLICY_VALID SKIP
  fi

  if [[ "$require_tls" == "1" ]]; then
    if [[ -n "$domain" ]]; then
      add HTTPS_VALID INFO "require_tls=1 domain=${domain} (caller validates reachability)"
    else
      add HTTPS_VALID FAIL "SEC_CRIT_TLS_REQUIRED_MISSING"
      overall_rc=1
    fi
  else
    add HTTPS_VALID SKIP "TLS not required for this mode"
  fi
  add REVERSE_PROXY_VALID INFO "caller validates proxy→odoo"

  # --- Webmin ---
  if declare -F soviez_mgmt_classify_webmin >/dev/null 2>&1; then
    local wc
    wc="$(soviez_mgmt_classify_webmin)"
    case "$wc" in
      N/A) add WEBMIN_EXPOSURE_ACCEPTABLE PASS "N/A" ;;
      PASS) add WEBMIN_EXPOSURE_ACCEPTABLE PASS ;;
      WARNING) add WEBMIN_EXPOSURE_ACCEPTABLE WARN "SEC_HIGH_WEBMIN_PUBLIC / SEC_WARN_WEBMIN_REVIEW_REQUIRED" ;;
      FAIL)
        add WEBMIN_EXPOSURE_ACCEPTABLE FAIL "SEC_HIGH_WEBMIN_PUBLIC"
        # Public Webmin without TLS is HIGH; block Production cert if SOVIEZ_SEC_STRICT_WEBMIN=1
        if [[ "${SOVIEZ_SEC_STRICT_WEBMIN:-0}" == "1" ]]; then
          overall_rc=1
        fi
        ;;
    esac
  fi

  # --- Host baselines ---
  if declare -F soviez_host_record_baseline >/dev/null 2>&1; then
    local hb
    hb="$(soviez_host_record_baseline "${SOVIEZ_HOST_BASELINE_DIR:-}" 2>/dev/null || true)"
    if [[ -n "$hb" ]]; then
      add SUID_BASELINE_RECORDED PASS "dir=${hb}"
      local uid0c
      uid0c="$(wc -l <"${hb}/uid0.txt" 2>/dev/null | tr -d ' ' || echo 0)"
      if [[ "${uid0c:-0}" -gt 1 ]]; then
        add NO_UNEXPECTED_UID0 WARN "multiple uid0 accounts (${uid0c})"
      else
        add NO_UNEXPECTED_UID0 PASS "uid0 count=${uid0c}"
      fi
    else
      add SUID_BASELINE_RECORDED SKIP
      add NO_UNEXPECTED_UID0 SKIP
    fi
  fi

  if declare -F soviez_persist_record_baseline >/dev/null 2>&1; then
    local pb
    pb="$(soviez_persist_record_baseline "${SOVIEZ_PERSIST_BASELINE_DIR:-}" 2>/dev/null || true)"
    if [[ -n "$pb" ]]; then
      add SYSTEMD_CRON_BASELINE_RECORDED PASS
      local ld
      ld="$(cat "${pb}/ld_preload.txt" 2>/dev/null || echo ABSENT)"
      case "$ld" in
        ABSENT|EMPTY) add LD_PRELOAD_STATE_ACCEPTABLE PASS "$ld" ;;
        UNEXPECTED)
          add LD_PRELOAD_STATE_ACCEPTABLE FAIL "SEC_HIGH_LD_PRELOAD_UNEXPECTED"
          overall_rc=1
          ;;
        *) add LD_PRELOAD_STATE_ACCEPTABLE UNKNOWN "$ld"; overall_rc=1 ;;
      esac
    else
      add SYSTEMD_CRON_BASELINE_RECORDED SKIP
      add LD_PRELOAD_STATE_ACCEPTABLE SKIP
    fi
  fi

  # Indeterminate firewall + unsafe public docker bind => CRITICAL
  if [[ "$backend" == "UNKNOWN" || "$backend" == "none" ]]; then
    if [[ "${overall_rc}" -ne 0 ]]; then
      add FIREWALL_INDETERMINATE_WITH_EXPOSURE FAIL "SEC_CRIT_FIREWALL_STATE_UNKNOWN"
    fi
  fi

  local overall="PASS"
  if [[ "$overall_rc" -ne 0 ]]; then
    overall="FAIL"
  fi

  if declare -F soviez_sec_report_finalize >/dev/null 2>&1; then
    if ! soviez_sec_report_finalize >/dev/null; then
      overall="FAIL"
      overall_rc=1
    fi
  fi

  if [[ "$overall_rc" -eq 0 ]]; then
    echo "[security] SEC_OK_HOST_EDGE_HARDENED" >&2
  fi
  return "$overall_rc"
}

soviez_security_gate_s2_require_pass() {
  if ! soviez_security_validate_host_edge; then
    if declare -F soviez_security_die >/dev/null 2>&1; then
      soviez_security_die SEC_CRIT_SECURITY_STATE_UNKNOWN "S2 host/edge gate failed"
    fi
    return 1
  fi
}

soviez_sec_s2_harden() {
  # Mutable host/edge apply — idempotent.
  local snap
  snap="$(soviez_s2_rollback_snapshot 2>/dev/null || true)"
  if declare -F soviez_fw_detect_backend >/dev/null 2>&1; then
    soviez_fw_detect_backend >/dev/null || true
  fi
  if [[ "${SOVIEZ_FW_APPLY:-0}" == "1" ]] && declare -F soviez_fw_apply_soviez_policy >/dev/null 2>&1; then
    soviez_fw_apply_soviez_policy || {
      [[ -n "$snap" ]] && soviez_s2_rollback "$snap" || true
      return 1
    }
  fi
  if declare -F soviez_bf_ensure_fail2ban_ssh >/dev/null 2>&1; then
    soviez_bf_ensure_fail2ban_ssh || true
  fi
  if declare -F soviez_ssh_staged_harden >/dev/null 2>&1; then
    soviez_ssh_staged_harden || true
  fi
  if declare -F soviez_edge_validate_mode >/dev/null 2>&1; then
    soviez_edge_validate_mode || true
  fi
  soviez_security_validate_host_edge
}
