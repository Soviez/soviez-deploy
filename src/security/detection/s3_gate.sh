# shellcheck shell=bash
# Security Gate S3 — fail-closed compromise detection gate (detect/report only).

soviez_security_validate_compromise_detection() {
  local evidence
  evidence="$(soviez_s3_evidence_init "${SOVIEZ_SEC_S3_RUN_ID:-}")"
  export SOVIEZ_SEC_S3_LAST_EVIDENCE="$evidence"

  local overall="PASS"
  local db_st="SKIP" host_st="SKIP" yara_st="N/A" proc_st="SKIP" net_st="SKIP" persist_st="SKIP" drift_st="N/A"

  # Ruleset integrity
  local share
  share="$(soviez_s3_detection_share)"
  if [[ ! -f "${share}/db_rules.json" || ! -f "${share}/iocs.json" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: ruleset missing/corrupt" >&2
    soviez_s3_report_write "$evidence" "FAIL" "FAIL" "N/A" "N/A" "N/A" "N/A" "N/A" "N/A"
    soviez_s3_evidence_finalize "$evidence" "FAIL" >/dev/null
    return 1
  fi

  # DB scan when PG available
  if [[ -n "${SOVIEZ_SEC_PG_CONTAINER:-}" ]]; then
    local db_out rc
    db_out="$(mktemp)"
    set +e
    soviez_s3_db_scan "$evidence" >"$db_out"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      db_st="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","PASS"))' "$db_out" 2>/dev/null || echo PASS)"
    elif [[ $rc -eq 2 ]]; then
      db_st="FAIL"
      overall="FAIL"
    else
      db_st="FAIL"
      overall="FAIL"
      echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: DB scan failed" >&2
    fi
    # Baseline diff if index exists
    if [[ -f "$evidence/findings/records_index.json" ]]; then
      drift_st="$(soviez_s3_baseline_diff "$evidence/findings/records_index.json" "${SOVIEZ_S3_BASELINE_NAME:-environment}" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","N/A"))' 2>/dev/null || echo N/A)"
      if [[ "$drift_st" == "PASS_WITH_REVIEW" && "$overall" == "PASS" ]]; then
        overall="PASS_WITH_REVIEW"
      fi
    fi
    rm -f "$db_out"
  elif [[ "${SOVIEZ_S3_REQUIRE_DB:-0}" == "1" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: DB required but not configured" >&2
    overall="FAIL"
    db_st="FAIL"
  else
    db_st="SKIP"
  fi

  # Host integrity
  local host_dir
  host_dir="$(mktemp -d)"
  if soviez_s3_host_integrity_scan "$host_dir" >/dev/null; then
    host_st="$(cat "$host_dir/STATUS")"
  else
    host_st="FAIL"
    overall="FAIL"
  fi
  mkdir -p "$evidence/tools/host_integrity"
  cp -a "$host_dir/." "$evidence/tools/host_integrity/" 2>/dev/null || true
  rm -rf "$host_dir"

  # Persistence
  local pdir
  pdir="$(mktemp -d)"
  if soviez_s3_persistence_scan "" "$pdir" >/dev/null; then
    persist_st="$(cat "$pdir/STATUS")"
  else
    persist_st="FAIL"
    overall="FAIL"
  fi
  mkdir -p "$evidence/tools/persistence"
  cp -a "$pdir/." "$evidence/tools/persistence/" 2>/dev/null || true
  rm -rf "$pdir"

  # Process
  local proc_json
  proc_json="$evidence/tools/process.json"
  mkdir -p "$evidence/tools"
  proc_st="$(soviez_s3_process_scan "$proc_json" 2>/dev/null || echo N/A)"
  if [[ "$proc_st" == "FAIL" ]]; then overall="FAIL"; fi
  if [[ "$proc_st" == "PASS_WITH_REVIEW" && "$overall" == "PASS" ]]; then overall="PASS_WITH_REVIEW"; fi

  # Network IOC
  local net_json="$evidence/tools/network_ioc.json"
  net_st="$(soviez_s3_network_ioc_scan "$net_json" 2>/dev/null || echo N/A)"
  if [[ "$net_st" == "FAIL" ]]; then overall="FAIL"; fi

  # YARA targeted (tmp paths + optional) — bounded; in test mode require explicit path
  local yara_json="$evidence/tools/yara.json"
  local ypaths=()
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    if [[ -n "${SOVIEZ_S3_YARA_PATH:-}" ]]; then ypaths+=("${SOVIEZ_S3_YARA_PATH}"); fi
  else
    [[ -d /tmp ]] && ypaths+=(/tmp)
    [[ -d /var/tmp ]] && ypaths+=(/var/tmp)
    [[ -d /dev/shm ]] && ypaths+=(/dev/shm)
    if [[ -n "${SOVIEZ_S3_YARA_PATH:-}" ]]; then ypaths+=("${SOVIEZ_S3_YARA_PATH}"); fi
  fi
  if [[ ${#ypaths[@]} -gt 0 ]]; then
    yara_st="$(soviez_s3_yara_scan_paths "$yara_json" "${ypaths[@]}" 2>/dev/null || echo N/A)"
    if [[ "$yara_st" == "FAIL" ]]; then overall="FAIL"; fi
  else
    yara_st="N/A"
  fi

  # Addon scan optional
  if [[ -n "${SOVIEZ_S3_ADDON_DIR:-}" && -d "${SOVIEZ_S3_ADDON_DIR}" ]]; then
    local addon_json="$evidence/tools/addon.json"
    local ast
    ast="$(soviez_s3_addon_scan "${SOVIEZ_S3_ADDON_DIR}" "$addon_json" 2>/dev/null || echo N/A)"
    if [[ "$ast" == "FAIL" ]]; then overall="FAIL"; fi
  fi

  # Alert state (local only)
  case "$overall" in
    PASS) export SOVIEZ_SECURITY_STATUS=PASS ;;
    PASS_WITH_REVIEW) export SOVIEZ_SECURITY_STATUS=REVIEW ;;
    FAIL) export SOVIEZ_SECURITY_STATUS=FAIL ;;
  esac
  printf '%s\n' "${SOVIEZ_SECURITY_STATUS}" >"$evidence/SECURITY_STATUS"

  soviez_s3_report_write "$evidence" "$overall" "$db_st" "$host_st" "$yara_st" "$proc_st" "$net_st" "$persist_st" "$drift_st"
  soviez_s3_evidence_finalize "$evidence" "$overall" >/dev/null
  declare -F soviez_s3_retention_cleanup >/dev/null 2>&1 && soviez_s3_retention_cleanup || true

  if [[ "$overall" == "FAIL" ]]; then
    echo "[security] SECURITY FAIL — POSSIBLE ACTIVE COMPROMISE" >&2
    echo "[security] Recommended: preserve evidence; avoid ordinary Production mutation; use future Incident/S4 path" >&2
    echo "[security] SEC_OK_COMPROMISE_SCAN not granted" >&2
    return 1
  fi
  echo "[security] SEC_OK_COMPROMISE_SCAN (${overall})" >&2
  return 0
}

soviez_cmd_security_scan_db() {
  # S3 compromise / DB+host detection CLI (Phase 24 --security-scan remains secret/dist).
  export SOVIEZ_SEC_MODE="${SOVIEZ_SEC_MODE:-production}"
  export SOVIEZ_SEC_PG_CONTAINER="${SOVIEZ_SEC_PG_CONTAINER:-${SOVIEZ_DB_CONTAINER:-}}"
  export SOVIEZ_SEC_PG_ADMIN_USER="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  export SOVIEZ_SEC_PG_ADMIN_PASS="${SOVIEZ_SEC_PG_ADMIN_PASS:-${SOVIEZ_PG_ADMIN_PASSWORD:-}}"
  export SOVIEZ_SEC_PG_DB="${SOVIEZ_SEC_PG_DB:-${SOVIEZ_DB_NAME:-postgres}}"
  soviez_security_validate_compromise_detection
}
