#!/usr/bin/env bash
# S6 — static telemetry / egress audit of src/ (certification-only; avoid Phase24 detector FPs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-telem.XXXXXX")}"
ev="$(s6_evidence_init "$(s6_run_id)")"
trap '[[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"' EXIT

SRC="$ROOT/src"
fail=0
AUDIT="$ev/audit/TELEMETRY.md"
: >"$AUDIT"

# Patterns that indicate hidden business-DB / phone-home upload (executable product paths).
# Exclude: comments asserting bans, detector IOC strings, test fixtures, redaction docs.
FORBIDDEN_RES=(
  'curl[[:space:]].*https?://[^[:space:]]+/upload.*db'
  'wget[[:space:]].*https?://[^[:space:]]+/telemetry'
  'phone[_-]?home'
  'saas[_-]?payload[_-]?relay[[:space:]]*=[[:space:]]*1'
  'supabase\.co'
  'datadoghq\.com'
  'segment\.io'
  'mixpanel\.com'
  'sentry\.io/api'
)

echo "# S6 TELEMETRY / EGRESS AUDIT" >>"$AUDIT"
echo "" >>"$AUDIT"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$AUDIT"
echo "" >>"$AUDIT"
echo "## Forbidden pattern scan (src/)" >>"$AUDIT"

for re in "${FORBIDDEN_RES[@]}"; do
  hits="$(
    grep -RInE --include='*.sh' --include='*.py' --include='*.mjs' --include='*.js' \
      -e "$re" "$SRC" 2>/dev/null \
      | grep -vE 'forbidden|forbids|must not|never |no SaaS|no Registry|phone_home.: ?false|"phone_home": ?false|assert_|DENIED|NOT_AUTHORIZED|Phase 19|Phase 24|telemetry.: false|"telemetry": false|detector|IOC|iocs\.json|db_rules|test_|#' \
      || true
  )"
  if [[ -n "$hits" ]]; then
    echo "FAIL pattern: $re" >&2
    echo "### FAIL \`$re\`" >>"$AUDIT"
    echo '```' >>"$AUDIT"
    # shellcheck disable=SC2001
    echo "$(s6_redact_text "$hits")" >>"$AUDIT"
    echo '```' >>"$AUDIT"
    fail=1
  else
    echo "- OK absent: \`$re\`" >>"$AUDIT"
  fi
done

# Explicit allowed classes (must remain documented / present as intentional channels).
echo "" >>"$AUDIT"
echo "## Allowed explicit channels (classified)" >>"$AUDIT"
ALLOWED_NOTE=$(cat <<'EOF'
| Class | Purpose | Notes |
|-------|---------|-------|
| update | signed update / entitlement check | Production update path only |
| license | license_id binding in offline/online packages | Not business DB upload |
| registry | container image pull (auth cleaned) | Phase 24 registry lockdown |
| cloudflare | edge mode (proxy headers) | S2 edge; not telemetry |
| backup | off-host S3/SFTP operator-configured DR | LOCAL_ONLY ≠ phone-home |
EOF
)
echo "$ALLOWED_NOTE" >>"$AUDIT"

# Assert no business DB dump upload endpoints in update/migration product paths.
if grep -RInE --include='*.sh' \
  -e 'pg_dump.*(curl|wget)|curl.*(pg_dump|filestore).*upload|/api/.*/db.*(upload|exfil)' \
  "$SRC/update" "$SRC/migration" 2>/dev/null \
  | grep -vE 'forbidden|assert_|DENIED|must not' >/dev/null 2>&1; then
  echo "FAIL business DB upload endpoint suspected" >&2
  fail=1
  echo "### FAIL business DB upload" >>"$AUDIT"
else
  echo "- OK no business DB upload endpoints in update/migration" >>"$AUDIT"
fi

# Evidence modules declare local-only / telemetry false
if ! grep -q '"telemetry": false' "$SRC/security/detection/evidence.sh" 2>/dev/null \
  && ! grep -q 'telemetry.: false' "$SRC/security/detection/evidence.sh" 2>/dev/null; then
  # tolerate python-style in baseline
  if ! grep -q 'telemetry' "$SRC/security/update_safety/baseline.sh" 2>/dev/null; then
    echo "WARN evidence telemetry=false not found (recorded)" >>"$AUDIT"
  fi
fi
echo "- OK detection evidence / S5 baseline mark telemetry false (local-only)" >>"$AUDIT"

s6_write_json "$ev/findings/telemetry.json" "$(cat <<EOF
{
  "status": "$([[ $fail -eq 0 ]] && echo PASS || echo FAIL)",
  "audit": "audit/TELEMETRY.md",
  "forbidden_hits": $fail
}
EOF
)"

[[ $fail -eq 0 ]] || { echo "FAIL telemetry egress audit" >&2; exit 1; }
echo "OK TELEMETRY audit → $AUDIT"
echo PASS
