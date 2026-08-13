# shellcheck shell=bash
# Security Gate S1 — critical containment evidence reports (no secrets).

SOVIEZ_SEC_REPORT_DIR="${SOVIEZ_SEC_REPORT_DIR:-}"
SOVIEZ_SEC_REPORT_ENTRIES=()

soviez_sec_report_init() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    dir="${SOVIEZ_SEC_REPORT_DIR:-${TMPDIR:-/tmp}/soviez-sec-report-$$}"
  fi
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  SOVIEZ_SEC_REPORT_DIR="$dir"
  SOVIEZ_SEC_REPORT_ENTRIES=()
  : >"$dir/report.partial"
  export SOVIEZ_SEC_REPORT_DIR
}

soviez_sec__report_redact() {
  local s="$1"
  # Redact password-like assignments and long secret-looking tokens without logging originals.
  s="$(printf '%s' "$s" | sed -E \
    -e 's/(password|passwd|secret|token|api[_-]?key|PGPASSWORD|ADMIN_PASS|APP_PASS)(=|:[[:space:]]*)[^[:space:],;]+/\1\2***REDACTED***/Ig' \
    -e 's/\b[A-Za-z0-9+\/_-]{40,}\b/***REDACTED***/g')"
  printf '%s' "$s"
}

soviez_sec_report_add() {
  local key="$1" rstatus="$2" detail="${3:-}"
  detail="$(soviez_sec__report_redact "$detail")"
  rstatus="$(printf '%s' "$rstatus" | tr '[:lower:]' '[:upper:]')"
  case "$rstatus" in
    PASS|FAIL|UNKNOWN|SKIP|INFO|WARN) ;;
    *) rstatus="UNKNOWN" ;;
  esac
  SOVIEZ_SEC_REPORT_ENTRIES+=("${key}|${rstatus}|${detail}")
  if [[ -n "${SOVIEZ_SEC_REPORT_DIR:-}" ]]; then
    printf '%s\t%s\t%s\n' "$key" "$rstatus" "$detail" >>"${SOVIEZ_SEC_REPORT_DIR}/report.partial"
  fi
}

soviez_sec_report_finalize() {
  local dir="${SOVIEZ_SEC_REPORT_DIR:-}"
  [[ -n "$dir" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: report dir unset" >&2; return 1; }
  mkdir -p "$dir"

  local overall="PASS"
  local entry key rstatus detail
  local pass_n=0 fail_n=0 unknown_n=0 skip_n=0 info_n=0 warn_n=0
  for entry in "${SOVIEZ_SEC_REPORT_ENTRIES[@]:-}"; do
    IFS='|' read -r key rstatus detail <<<"$entry"
    case "$rstatus" in
      PASS) pass_n=$((pass_n + 1)) ;;
      FAIL) fail_n=$((fail_n + 1)); overall="FAIL" ;;
      UNKNOWN) unknown_n=$((unknown_n + 1)); overall="FAIL" ;;
      SKIP) skip_n=$((skip_n + 1)) ;;
      INFO) info_n=$((info_n + 1)) ;;
      WARN) warn_n=$((warn_n + 1)) ;;
    esac
  done

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
  local mode="${SOVIEZ_SEC_MODE:-unknown}"

  {
    local gate_label="${SOVIEZ_SEC_GATE_LABEL:-S1}"
    echo "# Soviez Security Report (${gate_label})"
    echo "Overall: ${overall}"
    echo "Mode: ${mode}"
    echo "Generated (UTC): ${ts}"
    echo "Gate: ${gate_label}"
    echo "Counts: pass=${pass_n} fail=${fail_n} unknown=${unknown_n} skip=${skip_n} info=${info_n} warn=${warn_n}"
    echo
    echo "## Checks"
    for entry in "${SOVIEZ_SEC_REPORT_ENTRIES[@]:-}"; do
      IFS='|' read -r key rstatus detail <<<"$entry"
      if [[ -n "$detail" ]]; then
        printf '%s: %s — %s
' "$key" "$rstatus" "$detail"
      else
        printf '%s: %s
' "$key" "$rstatus"
      fi
    done
    echo
    if [[ "$overall" == "PASS" ]]; then
      if [[ "$gate_label" == "S2" ]]; then
        echo "Verdict: PASS — HOST & EDGE HARDENED"
        echo "Code: SEC_OK_HOST_EDGE_HARDENED"
      else
        echo "Verdict: PASS — CRITICAL CONTAINMENT"
        echo "Code: SEC_OK_CRITICAL_CONTAINMENT"
      fi
    else
      echo "Verdict: FAIL — ${gate_label} (fail-closed; UNKNOWN=FAIL)"
    fi
  } >"$dir/report.txt"

  # JSON without secrets (details already redacted).
  {
    printf '{'
    printf '"overall":"%s",' "$overall"
    printf '"mode":"%s",' "$(soviez_sec__report_json_escape "$mode")"
    printf '"generated_utc":"%s",' "$(soviez_sec__report_json_escape "$ts")"
    printf '"gate":"%s",' "$(soviez_sec__report_json_escape "${SOVIEZ_SEC_GATE_LABEL:-S1}")"
    printf '"counts":{"pass":%s,"fail":%s,"unknown":%s,"skip":%s,"info":%s,"warn":%s},' \
      "$pass_n" "$fail_n" "$unknown_n" "$skip_n" "$info_n" "$warn_n"
    printf '"checks":['
    local first=1
    for entry in "${SOVIEZ_SEC_REPORT_ENTRIES[@]:-}"; do
      IFS='|' read -r key rstatus detail <<<"$entry"
      [[ $first -eq 1 ]] || printf ','
      first=0
      printf '{"key":"%s","status":"%s","detail":"%s"}'         "$(soviez_sec__report_json_escape "$key")"         "$(soviez_sec__report_json_escape "$rstatus")"         "$(soviez_sec__report_json_escape "$detail")"
    done
    printf ']'
    if [[ "$overall" == "PASS" ]]; then
      if [[ "${SOVIEZ_SEC_GATE_LABEL:-S1}" == "S2" ]]; then
        printf ',"code":"SEC_OK_HOST_EDGE_HARDENED"'
      else
        printf ',"code":"SEC_OK_CRITICAL_CONTAINMENT"'
      fi
    fi
    printf '}\n'
  } >"$dir/report.json"

  chmod 600 "$dir/report.txt" "$dir/report.json" 2>/dev/null || true
  printf '%s\n' "$overall"
  [[ "$overall" == "PASS" ]]
}

soviez_sec__report_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}
