# shellcheck shell=bash
# Security Gate S3 — local-only evidence runs (no telemetry).

SOVIEZ_SEC_S3_RUN_ID="${SOVIEZ_SEC_S3_RUN_ID:-}"
SOVIEZ_SEC_S3_EVIDENCE_ROOT="${SOVIEZ_SEC_S3_EVIDENCE_ROOT:-}"

soviez_s3_detection_share() {
  if [[ -n "${SOVIEZ_S3_SHARE_DIR:-}" && -d "${SOVIEZ_S3_SHARE_DIR}" ]]; then
    printf '%s\n' "${SOVIEZ_S3_SHARE_DIR}"
    return 0
  fi
  local root="${SOVIEZ_SH_ROOT:-${SOVIEZ_ROOT:-.}}"
  local p="${root}/share/security/detection"
  printf '%s\n' "$p"
}

soviez_s3_evidence_root() {
  if [[ -n "${SOVIEZ_SEC_S3_EVIDENCE_ROOT:-}" ]]; then
    printf '%s\n' "$SOVIEZ_SEC_S3_EVIDENCE_ROOT"
    return 0
  fi
  local base="${SOVIEZ_ROOT:-/var/lib/soviez}/security/runs"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    base="${TMPDIR:-/tmp}/soviez-s3-evidence"
  fi
  printf '%s\n' "$base"
}

soviez_s3_evidence_init() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    run_id="s3-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  fi
  SOVIEZ_SEC_S3_RUN_ID="$run_id"
  export SOVIEZ_SEC_S3_RUN_ID
  local root
  root="$(soviez_s3_evidence_root)/${run_id}"
  mkdir -p "$root"/{findings,baselines,tools,hashes}
  chmod 700 "$(soviez_s3_evidence_root)" 2>/dev/null || true
  chmod 700 "$root" 2>/dev/null || true
  local share
  share="$(soviez_s3_detection_share)"
  local rules_hash ioc_hash ver
  ver="$(cat "${share}/schema_version" 2>/dev/null || echo unknown)"
  rules_hash="$(openssl dgst -sha256 "${share}/db_rules.json" 2>/dev/null | awk '{print $NF}' || echo missing)"
  ioc_hash="$(openssl dgst -sha256 "${share}/iocs.json" 2>/dev/null | awk '{print $NF}' || echo missing)"
  cat >"$root/run_meta.json" <<EOF
{
  "run_id": "$(soviez_s3__json_escape "$run_id")",
  "gate": "S3",
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scanner_version": "0.24.3-security-s3",
  "ruleset_version": "$(soviez_s3__json_escape "$ver")",
  "rules_sha256": "$(soviez_s3__json_escape "$rules_hash")",
  "ioc_sha256": "$(soviez_s3__json_escape "$ioc_hash")",
  "local_only": true,
  "telemetry": false,
  "destructive_remediation": false
}
EOF
  chmod 600 "$root/run_meta.json" 2>/dev/null || true
  printf '%s\n' "$root"
}

soviez_s3__json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

soviez_s3_evidence_write_findings() {
  local root="$1" json_file="$2"
  cp -f "$json_file" "$root/findings/findings.json"
  chmod 600 "$root/findings/findings.json" 2>/dev/null || true
}

soviez_s3_evidence_finalize() {
  local root="$1"
  local status="${2:-PASS}"
  # Manifest of file hashes
  local man="$root/hashes/manifest.sha256"
  : >"$man"
  local f
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    openssl dgst -sha256 "$f" 2>/dev/null | awk -v p="$f" '{print $NF"  "p}' >>"$man" || true
  done < <(find "$root" -type f ! -path '*/hashes/*' 2>/dev/null | sort)
  chmod 600 "$man" 2>/dev/null || true
  printf '%s\n' "$status" >"$root/STATUS"
  chmod 600 "$root/STATUS" 2>/dev/null || true
  # Human report stub filled by s3_report
  printf '%s\n' "$root"
}

soviez_s3_evidence_verify() {
  local root="$1"
  local man="$root/hashes/manifest.sha256"
  [[ -f "$man" ]] || return 1
  local line hash path actual
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    hash="$(printf '%s' "$line" | awk '{print $1}')"
    path="$(printf '%s' "$line" | awk '{print $2}')"
    [[ -f "$path" ]] || return 1
    actual="$(openssl dgst -sha256 "$path" 2>/dev/null | awk '{print $NF}')"
    [[ "$actual" == "$hash" ]] || return 1
  done <"$man"
  return 0
}
