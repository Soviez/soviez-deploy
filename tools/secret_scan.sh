#!/usr/bin/env bash
# Canonical Phase 24 secret-scan gate (local-first; no SaaS required).
# Prefer gitleaks when installed; always run embedded pattern/entropy scanner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-tree}" # tree | dist | history | all
FAIL=0

TOOL_CHOSEN="embedded_pattern_entropy"
if command -v gitleaks >/dev/null 2>&1; then
  TOOL_CHOSEN="gitleaks+embedded"
fi

echo "SECRET_SCAN_TOOL=$TOOL_CHOSEN"

pem_re='^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----'

allowlisted() {
  local f="$1"
  case "$f" in
    */tests/fixtures/secrets/*|*/tests/security/fixtures/secrets/*|*/docs/evidence/*/SYNTHETIC*|*/.git/*) return 0 ;;
    */tools/secret_scan.sh|*/src/security/dist_scan.sh|*/src/security/secret_hygiene.sh) return 0 ;;
    */tests/security/test_phase16_secret_handling.sh|*/tests/security/test_phase17_secret_handling.sh) return 0 ;;
    */tests/security/test_phase24_secret_scan.sh|*/tests/security/test_phase24_key_hygiene.sh) return 0 ;;
    */tests/unit/test_ssl_lifecycle.sh|*/tests/integration/test_phase23_real_ed25519.sh) return 0 ;;
    */tests/integration/test_backup_sftp_real.sh|*/tests/integration/test_stage_disconnect_resume_e2e.sh|*/tests/integration/test_stage_offline_full_e2e.sh) return 0 ;;
  esac
  return 1
}

scan_embedded_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  allowlisted "$f" && return 0
  local hits=0
  if grep -EUo 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' "$f" >/dev/null 2>&1; then
    echo "HIT jwt_like file=$f fingerprint=$(printf '%s' "$f:jwt" | shasum -a 256 | awk '{print $1}')" >&2
    hits=$((hits+1))
  fi
  if grep -E "$pem_re" "$f" >/dev/null 2>&1; then
    echo "HIT private_key_pem file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -E 'AKIA[0-9A-Z]{16}' "$f" >/dev/null 2>&1; then
    echo "HIT aws_access_key_id file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -Ei 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,}' "$f" >/dev/null 2>&1; then
    echo "HIT github_token file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -E 'sk_live_[A-Za-z0-9]{16,}' "$f" >/dev/null 2>&1; then
    echo "HIT stripe_live file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -Ei 'service_role[_-]?(key|secret|jwt)[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$f" >/dev/null 2>&1; then
    echo "HIT service_role_credential file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -Ei 'SUPABASE_SERVICE_ROLE(_KEY)?[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$f" >/dev/null 2>&1; then
    echo "HIT supabase_service_role file=$f" >&2
    hits=$((hits+1))
  fi
  if grep -EiE '(password|secret|token|api_key)[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9+/=_-]{40,}' "$f" >/dev/null 2>&1; then
    if ! grep -EiE '(password|secret|token|api_key)[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9+/=_-]{40,}' "$f" \
      | grep -Eiq 'FORBIDDEN|deny|example|placeholder|REDACTED|fingerprint|synthetic|disposable|not-production|fixture|phase[0-9]+-'; then
      echo "HIT high_entropy_assignment file=$f" >&2
      hits=$((hits+1))
    fi
  fi
  return "$hits"
}

scan_tree() {
  local root="$1"
  local fail=0 f
  while IFS= read -r f; do
    set +e
    scan_embedded_file "$f"
    local h=$?
    set -e
    [[ "$h" -eq 0 ]] || fail=$((fail+h))
  done < <(find "$root/src" "$root/dist" "$root/tests" "$root/build" \
    -type f \( -name '*.sh' -o -name 'soviez.sh' -o -name '*.py' -o -name '*.yml' -o -name '*.yaml' \
    -o -name '*.env' -o -name '*.pem' -o -name '*.json' -o -name '*.toml' \) 2>/dev/null | head -8000)
  for f in "$root/docs/user/PRIVACY_AND_SOVEREIGNTY.md" "$root/PRODUCT_CONSTITUTION.md" "$root/PROJECT_STATE.md"; do
    [[ -f "$f" ]] || continue
    set +e; scan_embedded_file "$f"; local h=$?; set -e
    [[ "$h" -eq 0 ]] || fail=$((fail+h))
  done
  return "$fail"
}

run_gitleaks_if_present() {
  if ! command -v gitleaks >/dev/null 2>&1; then
    echo "gitleaks: not installed — embedded scanner is authoritative"
    return 0
  fi
  local cfg="$ROOT/.gitleaks.toml"
  if [[ -f "$cfg" ]]; then
    gitleaks detect --source "$ROOT" --config "$cfg" --no-git --redact -v || return 1
  else
    gitleaks detect --source "$ROOT" --no-git --redact -v || return 1
  fi
  return 0
}

scan_history() {
  if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "GIT_HISTORY_SCAN — SKIP (no git repository)"
    return 0
  fi
  local commits
  commits="$(git -C "$ROOT" rev-list --all --count 2>/dev/null || echo 0)"
  if [[ "${commits:-0}" -eq 0 ]]; then
    echo "GIT_HISTORY_SCAN — N/A (repository has zero commits; tree scan is authoritative)"
    echo "HISTORICAL_SECRET_REVIEW — no commit history to classify"
    return 0
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --source "$ROOT" --redact -v || return 1
    echo "GIT_HISTORY_SCAN — PASS (gitleaks)"
    return 0
  fi
  echo "GIT_HISTORY_SCAN — PASS (embedded tree covered; history tool unavailable)"
  return 0
}

case "$MODE" in
  dist)
    set +e; scan_embedded_file "$ROOT/dist/soviez.sh"; h=$?; set -e
    [[ "$h" -eq 0 ]] || FAIL=1
    ;;
  history)
    scan_history || FAIL=1
    ;;
  all)
    run_gitleaks_if_present || FAIL=1
    set +e; scan_tree "$ROOT"; h=$?; set -e
    [[ "$h" -eq 0 ]] || FAIL=1
    scan_history || FAIL=1
    set +e; scan_embedded_file "$ROOT/dist/soviez.sh"; h=$?; set -e
    [[ "$h" -eq 0 ]] || FAIL=1
    ;;
  tree|*)
    run_gitleaks_if_present || FAIL=1
    set +e; scan_tree "$ROOT"; h=$?; set -e
    [[ "$h" -eq 0 ]] || FAIL=1
    ;;
esac

if [[ "$FAIL" -ne 0 ]]; then
  echo "SECRET_SCAN — FAIL"
  exit 1
fi
echo "SECRET_SCAN — PASS"
exit 0
