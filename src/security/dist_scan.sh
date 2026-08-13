# shellcheck shell=bash
# Phase 24 — dist / tree secret scan (no SaaS dependency).
# Patterns are assembled at runtime so this module does not contain raw secret markers.

soviez_security__pem_begin_re() {
  # Line-anchored PEM private-key header (requires dashes).
  printf '%s\n' '^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----'
}

soviez_security_scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local hits=0
  local pem_re
  pem_re="$(soviez_security__pem_begin_re)"

  # Credential-shaped JWT (three base64url segments) — high confidence
  if grep -EUo 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' "$file" >/dev/null 2>&1; then
    echo "HIT jwt_like file=$file" >&2
    hits=$((hits + 1))
  fi
  if grep -E "$pem_re" "$file" >/dev/null 2>&1; then
    echo "HIT private_key_pem file=$file" >&2
    hits=$((hits + 1))
  fi
  if grep -E 'AKIA[0-9A-Z]{16}' "$file" >/dev/null 2>&1; then
    echo "HIT aws_access_key_id file=$file" >&2
    hits=$((hits + 1))
  fi
  if grep -Ei 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' "$file" >/dev/null 2>&1; then
    echo "HIT github_token file=$file" >&2
    hits=$((hits + 1))
  fi
  if grep -E 'sk_live_[A-Za-z0-9]{16,}' "$file" >/dev/null 2>&1; then
    echo "HIT stripe_live_secret file=$file" >&2
    hits=$((hits + 1))
  fi
  # service_role *credential assignment* with long value — not deny-list identifiers
  if grep -Ei 'service_role[_-]?(key|secret|jwt)[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$file" >/dev/null 2>&1; then
    echo "HIT service_role_credential file=$file" >&2
    hits=$((hits + 1))
  fi
  if grep -Ei 'SUPABASE_SERVICE_ROLE(_KEY)?[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$file" >/dev/null 2>&1; then
    echo "HIT supabase_service_role file=$file" >&2
    hits=$((hits + 1))
  fi
  return "$hits"
}

soviez_security_scan_dist() {
  local art="${1:-}"
  if [[ -z "$art" ]]; then
    art="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/dist/soviez.sh"
    [[ -f "$art" ]] || art="${SOVIEZ_SH_ROOT:-.}/dist/soviez.sh"
  fi
  [[ -f "$art" ]] || { echo "DIST SECURITY SCAN — FAIL missing $art" >&2; return 1; }
  local rc=0
  set +e
  soviez_security_scan_file "$art"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    echo "DIST SECURITY SCAN — FAIL hits=$rc" >&2
    return 1
  fi
  echo "DIST SECURITY SCAN — PASS"
  return 0
}

soviez_security_scan_allowlisted_path() {
  local f="$1"
  case "$f" in
    */tests/fixtures/secrets/*|*/tests/security/fixtures/secrets/*|*/docs/evidence/*/SYNTHETIC*|*/.git/*)
      return 0 ;;
    */tools/secret_scan.sh|*/src/security/dist_scan.sh|*/src/security/secret_hygiene.sh)
      return 0 ;;
    # Known disposable-key generators / prior-phase security tests (synthetic only)
    */tests/security/test_phase16_secret_handling.sh|*/tests/security/test_phase17_secret_handling.sh)
      return 0 ;;
    */tests/security/test_phase24_secret_scan.sh|*/tests/security/test_phase24_key_hygiene.sh)
      return 0 ;;
    */tests/unit/test_ssl_lifecycle.sh|*/tests/integration/test_phase23_real_ed25519.sh)
      return 0 ;;
    */tests/integration/test_backup_sftp_real.sh|*/tests/integration/test_stage_disconnect_resume_e2e.sh|*/tests/integration/test_stage_offline_full_e2e.sh)
      return 0 ;;
  esac
  return 1
}

soviez_security_scan_tree() {
  local root="${1:-.}"
  local fail=0
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if soviez_security_scan_allowlisted_path "$f"; then
      continue
    fi
    set +e
    soviez_security_scan_file "$f"
    local h=$?
    set -e
    [[ "$h" -eq 0 ]] || fail=$((fail + h))
  done < <(find "$root/src" "$root/dist" "$root/tests" -type f \( -name '*.sh' -o -name 'soviez.sh' -o -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.yml' -o -name '*.yaml' -o -name '*.env' -o -name '*.pem' -o -name '*.json' \) 2>/dev/null | head -5000)
  [[ "$fail" -eq 0 ]] || return 1
  echo "TREE SECRET SCAN — PASS"
  return 0
}
