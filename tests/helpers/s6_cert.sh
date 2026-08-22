#!/usr/bin/env bash
# shellcheck shell=bash
# Security Gate S6 — certification-only helpers (evidence, hashing, TEST-SEC map).
# Does not modify product source; orchestrates S1–S5 certification evidence.

s6_cert_root() {
  local helper_root
  helper_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "${SOVIEZ_SH_ROOT:-$helper_root}"
}

s6_evidence_root() {
  if [[ -n "${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-}" ]]; then
    printf '%s\n' "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"
    return 0
  fi
  local base
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    base="${TMPDIR:-/tmp}/soviez-s6-evidence"
  else
    base="${SOVIEZ_ROOT:-/var/lib/soviez}/security/s6/runs"
  fi
  printf '%s\n' "$base"
}

s6_evidence_init() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    if declare -F s6_run_id >/dev/null 2>&1; then
      run_id="$(s6_run_id)"
    else
      run_id="s6-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    fi
  fi
  export SOVIEZ_SEC_S6_RUN_ID="$run_id"
  local root
  root="$(s6_evidence_root)/${run_id}"
  mkdir -p "$root"/{findings,hashes,matrix,audit,artifacts}
  chmod 700 "$(s6_evidence_root)" 2>/dev/null || true
  chmod 700 "$root" 2>/dev/null || true
  cat >"$root/run_meta.json" <<EOF
{
  "run_id": "$(s6_json_escape "$run_id")",
  "gate": "S6",
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "certification_only": true,
  "telemetry": false,
  "local_only": true
}
EOF
  chmod 600 "$root/run_meta.json" 2>/dev/null || true
  printf '%s\n' "$root"
}

s6_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

s6_hash_file() {
  local f="${1:?}"
  if [[ ! -f "$f" ]]; then
    echo "missing" >&2
    return 1
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    openssl dgst -sha256 "$f" 2>/dev/null | awk '{print $NF}'
  fi
}

s6_redact_text() {
  local s="${1:-}"
  if declare -F soviez_redact_text >/dev/null 2>&1; then
    soviez_redact_text "$s"
    return 0
  fi
  # Certification fallback: scrub common secret shapes (not a product redact engine).
  s="$(printf '%s' "$s" | sed -E \
    -e 's/(password|passwd|secret|token|api[_-]?key)(=|[[:space:]]*:[[:space:]]*)[^[:space:]"]+/\1\2***REDACTED***/Ig' \
    -e 's/AKIA[0-9A-Z]{16}/***REDACTED_AWS***/g' \
    -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----/***REDACTED_PEM***/g')"
  printf '%s' "$s"
}

s6_write_json() {
  local path="${1:?}"
  local body="${2:?}"
  printf '%s\n' "$body" >"$path"
  chmod 600 "$path" 2>/dev/null || true
}

# Canonical expected cert artifact = VERSION + assembled dist digest (current candidate).
# Override via env when pinning a historical SHA. Do not freeze a prior release SHA here.
_s6_root="$(s6_cert_root)"
S6_EXPECTED_VERSION="${S6_EXPECTED_VERSION:-$(tr -d '[:space:]' <"${_s6_root}/VERSION" 2>/dev/null || true)}"
if [[ -z "${S6_EXPECTED_DIST_SHA256:-}" ]]; then
  if [[ -f "${_s6_root}/dist/soviez.sh.sha256" ]]; then
    S6_EXPECTED_DIST_SHA256="$(awk '{print $1; exit}' "${_s6_root}/dist/soviez.sh.sha256")"
  elif [[ -f "${_s6_root}/dist/soviez.sh" ]]; then
    S6_EXPECTED_DIST_SHA256="$(s6_hash_file "${_s6_root}/dist/soviez.sh")"
  fi
fi
unset _s6_root

# TEST-SEC-001..024 → existing platform / S2–S5 scripts (certification map).
s6_test_sec_map_json() {
  cat <<'EOF'
{
  "TEST-SEC-001": ["tests/security/platform/test_pg_least_privilege.sh"],
  "TEST-SEC-002": ["tests/security/platform/test_pg_copy_program_denied.sh"],
  "TEST-SEC-003": ["tests/security/platform/test_pg_server_files_denied.sh"],
  "TEST-SEC-004": ["tests/security/platform/test_pg_server_files_denied.sh"],
  "TEST-SEC-005": ["tests/security/platform/test_pg_network_isolation.sh"],
  "TEST-SEC-006": ["tests/security/platform/test_odoo_port_isolation.sh"],
  "TEST-SEC-007": ["tests/security/platform/test_nginx_hardening.sh"],
  "TEST-SEC-008": ["tests/security/platform/test_s2_real_runtime.sh"],
  "TEST-SEC-009": ["tests/security/platform/test_odoo_functional_least_privilege.sh"],
  "TEST-SEC-010": ["tests/security/update_safety/test_s5_docker_restart_matrix.sh"],
  "TEST-SEC-011": ["tests/security/update_safety/test_s5_network_fault_inject.sh"],
  "TEST-SEC-012": ["tests/security/platform/test_s2_restart_matrix.sh"],
  "TEST-SEC-013": ["tests/security/platform/test_s2_restart_matrix.sh"],
  "TEST-SEC-014": ["tests/security/platform/test_weak_credentials.sh"],
  "TEST-SEC-015": ["tests/security/platform/test_pg_least_privilege.sh"],
  "TEST-SEC-016": ["tests/security/platform/test_docker_containment.sh"],
  "TEST-SEC-017": ["tests/security/detection/test_db_classifier_fixtures.sh"],
  "TEST-SEC-018": ["tests/security/detection/test_db_scan_real_odoo_schema.sh"],
  "TEST-SEC-019": ["tests/security/quarantine/test_network_egress_cron.sh"],
  "TEST-SEC-020": ["tests/security/backup_safety/test_s5_backup_integrity_posture.sh", "tests/security/quarantine/test_state_promotion.sh"],
  "TEST-SEC-021": ["tests/security/detection/test_db_scan_real_odoo_schema.sh"],
  "TEST-SEC-022": ["tests/security/detection/test_evidence_failclosed_retention.sh"],
  "TEST-SEC-023": ["tests/security/platform/test_s1_idempotency.sh", "tests/security/platform/test_s2_idempotency.sh"],
  "TEST-SEC-024": ["tests/security/update_safety/test_s5_firewall_reboot_guest.sh", "tests/security/platform/test_s2_firewall_guest.sh"]
}
EOF
}

s6_test_sec_scripts_for() {
  local id="${1:?}"
  # Use -c so stdin remains available for the map JSON pipe.
  s6_test_sec_map_json | python3 -c '
import json,sys
mid=sys.argv[1]
m=json.load(sys.stdin)
for s in m.get(mid,[]) or []:
  print(s)
' "$id"
}

s6_canonical_modules_present() {
  # Dist must contain S5 APT wait, quarantine, and detection owners.
  local dist="${1:?}"
  local miss=0
  local needle
  for needle in \
    soviez_s5_apt_wait_for_lock \
    soviez_q_create \
    soviez_s3_db_scan \
    soviez_security_validate_quarantine \
    soviez_sec_legacy_assert_apt_lock_safe
  do
    if ! grep -q "$needle" "$dist" 2>/dev/null; then
      echo "MISSING_MODULE:$needle" >&2
      miss=1
    fi
  done
  return "$miss"
}
