#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/p25_cert.sh"
mkdir -p "$EVID/audit"
DIFF="$EVID/audit/DOCUMENTATION_DIFF.md"
SYNC="$EVID/audit/DOCUMENTATION_SYNC.md"
: >"$DIFF"
fail=0
scan_docs() {
  local pattern="$1" label="$2"
  local hits
  hits="$(rg -n "$pattern" \
    "$ROOT/docs/installation" "$ROOT/docs/operations" "$ROOT/docs/security" \
    "$ROOT/docs/migration" "$ROOT/docs/backup" "$ROOT/docs/licensing" \
    "$ROOT/docs/offline" "$ROOT/docs/stage" "$ROOT/docs/registry" \
    "$ROOT/PRODUCT_CONSTITUTION.md" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    echo "## FAIL: $label" >>"$DIFF"
    echo '```' >>"$DIFF"
    echo "$hits" >>"$DIFF"
    echo '```' >>"$DIFF"
    fail=1
  fi
}
# Stale authoritative current-version claims (exclude historical evidence/decision context)
if rg -n 'current.*0\.24\.4-security-s4|installer.*0\.24\.4-security-s4' \
  "$ROOT/docs" --glob '*.md' --glob '!docs/evidence/**' 2>/dev/null | rg -v 'historical|prior|Prior|was |D12[0-9]|Phase 24 remains|paused' >/tmp/p25-doc-stale.txt 2>/dev/null; then
  if [[ -s /tmp/p25-doc-stale.txt ]]; then
    echo "## WARN: stale 0.24.4 references (review)" >>"$DIFF"
    cat /tmp/p25-doc-stale.txt >>"$DIFF"
  fi
fi
if rg -n 'heal_apt_locks|run killall|use killall' \
  "$ROOT/docs/installation" "$ROOT/docs/operations" "$ROOT/docs/security" \
  "$ROOT/docs/migration" "$ROOT/docs/backup" "$ROOT/docs/licensing" \
  "$ROOT/docs/offline" "$ROOT/docs/stage" "$ROOT/docs/registry" 2>/dev/null \
  | rg -v 'No `killall|never killall|do not killall|NEVER' >/tmp/p25-apt-bad.txt 2>/dev/null; then
  if [[ -s /tmp/p25-apt-bad.txt ]]; then
    echo "## FAIL: apt killall endorsement in operator docs" >>"$DIFF"
    cat /tmp/p25-apt-bad.txt >>"$DIFF"
    fail=1
  fi
fi
if rg -n 'Soviez\.sh (installs|will install|bundles).*Virtualmin' \
  "$ROOT/docs/installation" "$ROOT/docs/operations" "$ROOT/docs/security" \
  "$ROOT/docs/migration" "$ROOT/docs/backup" "$ROOT/docs/licensing" \
  "$ROOT/docs/offline" "$ROOT/docs/stage" "$ROOT/docs/registry" 2>/dev/null \
  | rg -v 'NEVER|never|does not install|do not install' >/tmp/p25-vmin-bad.txt 2>/dev/null; then
  if [[ -s /tmp/p25-vmin-bad.txt ]]; then
    echo "## FAIL: Virtualmin install implication" >>"$DIFF"
    cat /tmp/p25-vmin-bad.txt >>"$DIFF"
    fail=1
  fi
fi
# Webmin/Virtualmin invariant doc must exist
if ! rg -q 'NEVER installs Webmin|never installs Webmin|does not install Webmin' \
  "$ROOT/docs/security/WEBMIN_VIRTUALMIN.md" 2>/dev/null; then
  echo "## FAIL: WEBMIN_VIRTUALMIN.md missing never-install statement" >>"$DIFF"
  fail=1
fi
# Current artifact must appear in PROJECT_STATE
if ! rg -q "$P25_EXPECTED_SHA256" "$ROOT/PROJECT_STATE.md"; then
  echo "## FAIL: PROJECT_STATE missing current SHA ($P25_EXPECTED_SHA256)" >>"$DIFF"
  fail=1
fi
if ! rg -q "$P25_EXPECTED_VERSION" "$ROOT/PROJECT_STATE.md"; then
  echo "## FAIL: PROJECT_STATE missing current version ($P25_EXPECTED_VERSION)" >>"$DIFF"
  fail=1
fi
{
  echo "# DOCUMENTATION_SYNC"
  echo
  echo "scanned: docs/, PRODUCT_CONSTITUTION.md, PROJECT_STATE.md"
  echo "virtualmin_invariant: Soviez.sh NEVER installs Webmin or Virtualmin"
  echo "artifact_version=$P25_EXPECTED_VERSION"
  echo "artifact_sha256=$P25_EXPECTED_SHA256"
  if [[ $fail -eq 0 ]]; then
    echo "result=PASS"
  else
    echo "result=FAIL"
  fi
} >"$SYNC"
cp "$SYNC" "$EVID/DOCUMENTATION_SYNC.md"
cp "$DIFF" "$EVID/DOCUMENTATION_DIFF.md"
[[ $fail -eq 0 ]] || exit 1
echo "OK docs_sync"
exit 0
