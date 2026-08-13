#!/usr/bin/env bash
# Phase 24 — unsigned self-update must be absent / unreachable in production path.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Prefer rg; fall back to grep
search() {
  local pat="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pat" "$@" || return 1
  else
    grep -RnE "$pat" "$@" || return 1
  fi
}

# Production src must not contain curl|bash self-update or checksum-only execute
set +e
hits="$(search 'curl[^|]*\|[[:space:]]*bash|wget[^|]*\|[[:space:]]*(ba)?sh' src dist/soviez.sh 2>/dev/null | grep -v 'test_\|docs/' || true)"
set -e
[[ -z "$hits" ]] || { echo "FAIL unsigned pipe-to-shell in production tree:" >&2; echo "$hits" >&2; exit 1; }

# Soft STRICT_SIG default-off must be gone from release path
if grep -n 'SOVIEZ_UPDATE_STRICT_SIG:-0' src/update/release.sh >/dev/null 2>&1; then
  echo "FAIL soft STRICT_SIG default remains in release.sh" >&2
  exit 1
fi

# Privacy doc must not advertise optional unsigned self-update
if grep -qi 'optional script self-update' docs/user/PRIVACY_AND_SOVEREIGNTY.md 2>/dev/null; then
  echo "FAIL stale self-update language in PRIVACY_AND_SOVEREIGNTY.md" >&2
  exit 1
fi

echo "OK test_phase24_self_update_signature"
exit 0
