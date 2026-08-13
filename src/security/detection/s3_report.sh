# shellcheck shell=bash
# Security Gate S3 — human + machine compromise detection report.

soviez_s3_report_write() {
  local root="$1"
  local overall="${2:-PASS}"
  local db_st="${3:-N/A}"
  local host_st="${4:-N/A}"
  local yara_st="${5:-N/A}"
  local proc_st="${6:-N/A}"
  local net_st="${7:-N/A}"
  local persist_st="${8:-N/A}"
  local drift_st="${9:-N/A}"

  {
    echo "SOVIEZ SECURITY — COMPROMISE DETECTION"
    echo "Database persistence scan: ${db_st}"
    echo "Known IOC scan: included-in-DB"
    echo "Technical baseline drift: ${drift_st}"
    echo "Host integrity baseline: ${host_st}"
    echo "YARA targeted scan: ${yara_st}"
    echo "Process/miner indicators: ${proc_st}"
    echo "Known malicious outbound IOC: ${net_st}"
    echo "Cron/systemd / LD_PRELOAD persistence: ${persist_st}"
    echo "OVERALL: ${overall}"
    echo
    echo "Language: no known high-confidence technical persistence/IOC claimed clean beyond scan coverage."
    echo "Destructive remediation: NOT performed (S3 detect-only)."
    echo "Telemetry: none (local-only evidence)."
  } >"$root/report.txt"
  chmod 600 "$root/report.txt" 2>/dev/null || true

  cat >"$root/report.json" <<EOF
{
  "gate": "S3",
  "overall": "$(soviez_s3__json_escape "$overall")",
  "database_persistence": "$(soviez_s3__json_escape "$db_st")",
  "host_integrity": "$(soviez_s3__json_escape "$host_st")",
  "yara": "$(soviez_s3__json_escape "$yara_st")",
  "process": "$(soviez_s3__json_escape "$proc_st")",
  "network_ioc": "$(soviez_s3__json_escape "$net_st")",
  "persistence": "$(soviez_s3__json_escape "$persist_st")",
  "baseline_drift": "$(soviez_s3__json_escape "$drift_st")",
  "code": "SEC_OK_COMPROMISE_SCAN",
  "local_only": true,
  "destructive_remediation": false
}
EOF
  chmod 600 "$root/report.json" 2>/dev/null || true
}
