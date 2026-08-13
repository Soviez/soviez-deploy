# shellcheck shell=bash
# Security Gate S5 — authoritative update safety gate + CLI.

soviez_security_validate_update_safety() {
  local op_id="${1:-${SOVIEZ_S5_OP_ID:-}}"
  [[ -n "$op_id" ]] || op_id="s5-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  export SOVIEZ_S5_OP_ID="$op_id"

  local d
  d="$(soviez_s5_op_dir "$op_id")"
  local overall="PASS"
  local rolled_back=0
  local needs_action=0

  # --- PRE baseline ---
  export SOVIEZ_S5_BASELINE_PHASE=pre
  local pre_json
  pre_json="$(soviez_s5_baseline_capture "$op_id")" || {
    overall="FAILED_PRECHECK"
    soviez_s5_report_write "$d" "$overall" >/dev/null
    echo "$overall"
    return 1
  }

  # Pre matrix (fail closed on material FAIL)
  local c_odoo_pg c_dns c_ports c_nginx c_outbound c_pdf
  c_odoo_pg="$(soviez_s5_check_odoo_pg 2>/dev/null)" || c_odoo_pg="FAIL"
  c_dns="$(soviez_s5_check_dns 2>/dev/null)" || c_dns="FAIL"
  c_ports="$(soviez_s5_check_ports_protected 2>/dev/null)" || c_ports="FAIL"
  c_nginx="$(soviez_s5_check_nginx_upstream 2>/dev/null)" || c_nginx="FAIL"
  c_outbound="$(soviez_s5_check_outbound 2>/dev/null)" || c_outbound="FAIL"
  c_pdf="$(soviez_s5_check_pdf 2>/dev/null)" || c_pdf="FAIL"
  [[ -n "$c_odoo_pg" ]] || c_odoo_pg="FAIL"
  [[ -n "$c_dns" ]] || c_dns="FAIL"
  [[ -n "$c_ports" ]] || c_ports="FAIL"
  [[ -n "$c_nginx" ]] || c_nginx="SKIP"
  [[ -n "$c_outbound" ]] || c_outbound="FAIL"
  [[ -n "$c_pdf" ]] || c_pdf="FAIL"

  # Enrich pre baseline placeholders with live results.
  python3 - "$pre_json" "$c_dns" "$c_outbound" "$c_odoo_pg" <<'PY'
import json,sys
p,dns,out,db=sys.argv[1:5]
m=json.load(open(p))
m["dns"]=dns
m["outbound"]=out
m["db_connectivity"]=db
json.dump(m, open(p,"w"), indent=2)
PY

  for v in "$c_odoo_pg" "$c_dns" "$c_ports"; do
    if [[ "$v" == "FAIL" ]]; then
      overall="FAILED_PRECHECK"
    fi
  done
  if [[ "$c_outbound" == "FAIL" ]]; then
    overall="FAILED_PRECHECK"
  fi
  if [[ "$c_pdf" == "FAIL" && "${SOVIEZ_S5_PDF_N_A:-0}" != "1" ]]; then
    overall="FAILED_PRECHECK"
  fi

  if [[ "$overall" == "FAILED_PRECHECK" ]]; then
    python3 - "$d/checks/validation.json" "$c_odoo_pg" "$c_dns" "$c_ports" "$c_nginx" "$c_outbound" "$c_pdf" "$overall" <<'PY'
import json,sys
path=sys.argv[1]
keys=["odoo_pg","dns","ports_protected","nginx_upstream","outbound","pdf"]
vals=sys.argv[2:8]
overall=sys.argv[8]
obj={"checks":dict(zip(keys,vals)),"overall":overall,"phase":"pre"}
json.dump(obj, open(path,"w"), indent=2)
PY
    soviez_s5_report_write "$d" "$overall" >/dev/null
    echo "$overall"
    return 1
  fi

  # --- Optional mutation hook (update/restart performed by caller) ---
  # Post baseline + matrix.
  export SOVIEZ_S5_BASELINE_PHASE=post
  local post_json
  post_json="$(soviez_s5_baseline_capture "$op_id")"

  local p_odoo_pg p_dns p_ports p_nginx p_outbound p_pdf p_diff
  p_odoo_pg="$(soviez_s5_check_odoo_pg 2>/dev/null)" || p_odoo_pg="FAIL"
  p_dns="$(soviez_s5_check_dns 2>/dev/null)" || p_dns="FAIL"
  p_ports="$(soviez_s5_check_ports_protected 2>/dev/null)" || p_ports="FAIL"
  p_nginx="$(soviez_s5_check_nginx_upstream 2>/dev/null)" || p_nginx="FAIL"
  p_outbound="$(soviez_s5_check_outbound 2>/dev/null)" || p_outbound="FAIL"
  p_pdf="$(soviez_s5_check_pdf 2>/dev/null)" || p_pdf="FAIL"
  [[ -n "$p_odoo_pg" ]] || p_odoo_pg="FAIL"
  [[ -n "$p_dns" ]] || p_dns="FAIL"
  [[ -n "$p_ports" ]] || p_ports="FAIL"
  [[ -n "$p_nginx" ]] || p_nginx="SKIP"
  [[ -n "$p_outbound" ]] || p_outbound="FAIL"
  [[ -n "$p_pdf" ]] || p_pdf="FAIL"

  python3 - "$post_json" "$p_dns" "$p_outbound" "$p_odoo_pg" <<'PY'
import json,sys
p,dns,out,db=sys.argv[1:5]
m=json.load(open(p))
m["dns"]=dns
m["outbound"]=out
m["db_connectivity"]=db
json.dump(m, open(p,"w"), indent=2)
PY

  p_diff="$(soviez_s5_semantic_diff "$pre_json" "$post_json" 2>/dev/null)" || p_diff="FAIL"
  [[ -n "$p_diff" ]] || p_diff="FAIL"

  # Docker restart validation when requested.
  local p_restart="SKIP"
  if [[ "${SOVIEZ_S5_RUN_DOCKER_RESTART:-0}" == "1" ]]; then
    p_restart="$(soviez_s5_docker_restart_validate 2>/dev/null)" || p_restart="FAIL"
    [[ -n "$p_restart" ]] || p_restart="FAIL"
  fi

  local reboot_req svc_req ua_st apt_safe docker_disrupt
  reboot_req="$(soviez_s5_detect_reboot_required)"
  svc_req="$(soviez_s5_detect_service_restart_required)"
  ua_st="$(soviez_s5_unattended_upgrades_status)"
  apt_safe="$(soviez_s5_apt_lock_healer_safe 2>/dev/null)" || apt_safe="UNSAFE"
  [[ -n "$apt_safe" ]] || apt_safe="UNSAFE"
  docker_disrupt="$(soviez_s5_docker_package_update_is_disruptive)"

  # Material post failures → not PASS (containers-up alone never wins).
  local material_fail=0
  for v in "$p_odoo_pg" "$p_dns" "$p_ports" "$p_diff" "$p_restart"; do
    [[ "$v" == "FAIL" ]] && material_fail=1
  done
  [[ "$p_outbound" == "FAIL" ]] && material_fail=1
  if [[ "$p_pdf" == "FAIL" && "${SOVIEZ_S5_PDF_N_A:-0}" != "1" ]]; then
    material_fail=1
  fi
  [[ "$apt_safe" == "UNSAFE" ]] && material_fail=1

  python3 - "$d/checks/validation.json" \
    "$p_odoo_pg" "$p_dns" "$p_ports" "$p_nginx" "$p_outbound" "$p_pdf" "$p_diff" "$p_restart" \
    "$reboot_req" "$svc_req" "$ua_st" "$apt_safe" "$docker_disrupt" <<'PY'
import json,sys
path=sys.argv[1]
keys=["odoo_pg","dns","ports_protected","nginx_upstream","outbound","pdf",
      "semantic_diff","docker_restart","reboot_required","service_restart_required",
      "unattended_upgrades","apt_lock_healer","docker_package_disruptive"]
vals=sys.argv[2:]
obj={"checks":dict(zip(keys,vals)),"overall":"PENDING","phase":"post"}
json.dump(obj, open(path,"w"), indent=2)
PY

  if [[ "$material_fail" -eq 1 ]]; then
    if [[ "$(soviez_s5_should_rollback "$d/checks/validation.json")" == "true" ]]; then
      if [[ "${SOVIEZ_S5_PERFORM_ROLLBACK:-0}" == "1" ]] \
        && declare -F soviez_update_rollback >/dev/null 2>&1; then
        if soviez_update_rollback "$op_id" >/dev/null 2>&1 \
          && soviez_s5_assert_rollback_not_insecure >/dev/null 2>&1; then
          overall="ROLLED_BACK"
          rolled_back=1
        else
          overall="NEEDS_ACTION"
          needs_action=1
        fi
      else
        # Rollback indicated but not executed / not available.
        if [[ "${SOVIEZ_S5_ALLOW_NEEDS_ACTION:-1}" == "1" ]]; then
          overall="NEEDS_ACTION"
          needs_action=1
        else
          overall="FAIL"
        fi
      fi
    else
      overall="FAIL"
    fi
  else
    overall="PASS"
  fi

  python3 - "$d/checks/validation.json" "$overall" <<'PY'
import json,sys
p,ov=sys.argv[1],sys.argv[2]
m=json.load(open(p))
m["overall"]=ov
m["containers_up_alone_insufficient"]=True
json.dump(m, open(p,"w"), indent=2)
PY

  soviez_s5_report_write "$d" "$overall" >/dev/null

  case "$overall" in
    PASS)
      echo "[security] SEC_OK_UPDATE_SAFETY ${overall}" >&2
      echo "$overall"
      return 0
      ;;
    ROLLED_BACK)
      echo "[security] SEC_WARN_UPDATE_ROLLED_BACK" >&2
      echo "$overall"
      return 0
      ;;
    NEEDS_ACTION)
      echo "[security] SEC_HIGH_UPDATE_NEEDS_ACTION" >&2
      echo "$overall"
      return 1
      ;;
    FAILED_PRECHECK)
      echo "[security] SEC_CRIT_UPDATE_PRECHECK_FAILED" >&2
      echo "$overall"
      return 1
      ;;
    *)
      echo "[security] SEC_HIGH_UPDATE_SAFETY_FAILED (${overall})" >&2
      echo "$overall"
      return 1
      ;;
  esac
}

soviez_cmd_security_update_check() {
  export SOVIEZ_TEST_MODE="${SOVIEZ_TEST_MODE:-0}"
  local op_id="${SOVIEZ_CLI_S5_OP_ID:-${SOVIEZ_S5_OP_ID:-}}"
  local result
  result="$(soviez_security_validate_update_safety "$op_id")"
  local rc=$?
  echo "overall=${result}"
  echo "op_id=${SOVIEZ_S5_OP_ID:-}"
  echo "evidence=$(soviez_s5_op_dir "${SOVIEZ_S5_OP_ID}")"
  # Explicit: never claim success from containers-up alone (documented in report).
  return "$rc"
}
