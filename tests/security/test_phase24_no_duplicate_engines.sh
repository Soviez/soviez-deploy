#!/usr/bin/env bash
# Prove Phase 24 did not create duplicate engines.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# No second update/backup/entitlement/registry engines under security/
for pat in 'soviez_update_run|soviez_backup_run|soviez_entitlement_resolve|soviez_registry_create_pull_session'; do
  if grep -RE "$pat" src/security >/dev/null 2>&1; then
    echo "FAIL security modules redefine engine symbol matching $pat" >&2
    exit 1
  fi
done

# Security modules are adapters (helpers/die/assert only)
grep -q 'soviez_security_' src/security/signatures.sh
grep -q 'Phase 24' src/security/codes.sh

# Single VERSION / assemble path
[[ -f VERSION ]]
[[ -f build/assemble.sh ]]

echo "NO DUPLICATE ENGINE — PASS"
echo "OK test_phase24_no_duplicate_engines"
exit 0
