#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
tmp="$(mktemp -d)"
export SOVIEZ_S2_ROLLBACK_DIR="$tmp"
snap="$(soviez_s2_rollback_snapshot "$tmp")"
soviez_s2_rollback "$snap"
# Must not restore SUPERUSER semantics (S1) — rollback module has no PG SUPERUSER restore
! grep -Rni 'ALTER ROLE.*SUPERUSER' "$ROOT/src/security/platform/s2_rollback.sh" >/dev/null
echo PASS
rm -rf "$tmp"
