# shellcheck shell=bash
# Security Gate S3 — auditd / Lynis / optional tooling decisions (no heavy install by default).

soviez_s3_auditd_decision() {
  # Narrow watches only if auditd present; do not install huge syscall policy.
  if command -v auditctl >/dev/null 2>&1; then
    printf '%s\n' "AVAILABLE_NARROW_WATCHES_OPTIONAL"
  else
    printf '%s\n' "N/A_CONFIG_ONLY"
  fi
}

soviez_s3_lynis_decision() {
  printf '%s\n' "SUPPORTING_ONLY_ON_DEMAND"
}

soviez_s3_optional_tools_status() {
  cat <<'EOF'
{
  "clamav": "DEFERRED_ON_DEMAND_NOT_DEFAULT",
  "wazuh": "REJECTED_NO_SERVER_INFRA",
  "falco": "DEFERRED",
  "osquery": "DEFERRED",
  "crowdsec": "OPTIONAL_S2_OD",
  "aide": "DEFERRED_NATIVE_FINGERPRINTS",
  "yara": "TARGETED_OFFLINE_CURATED",
  "auditd": "NARROW_OPTIONAL",
  "lynis": "SUPPORTING_ONLY"
}
EOF
}
