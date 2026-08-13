#!/usr/bin/env bash
# Phase 17 — static gates: no payload transfer / DNS / token burn / activation / unsigned latest
# Phase 19/22: allow pg_dump/pg_restore ONLY under authorized migration paths:
# database/, filestore/, transfer/, stages/, staging/, source_archive/ (Phase 22).
# Still forbid SaaS relay, token burn, DNS mutation, StrictHostKeyChecking=no,
# broad rsync of host roots.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"

fail=0

P19_PAYLOAD_ALLOW='src/migration/database/|src/migration/filestore/|src/migration/transfer/|src/migration/stages/|src/migration/staging/|src/migration/source_archive/'

# Explicit scans — allow forbid/deny documentation lines and Phase 19/22 authorized paths
if rg -n --glob 'src/migration/**' -e 'pg_dump|pg_restore' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE "$P19_PAYLOAD_ALLOW" \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never|pg_dump -Fc' >/dev/null 2>&1; then
  echo "FAIL: pg_dump/pg_restore outside authorized Phase 19/22 paths"; fail=1
fi
if rg -n --glob 'src/migration/**' -e 'begin_license_migration|consume_ip_migration_token|migrate_license_ip' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never|Phase 20' >/dev/null 2>&1; then
  echo "FAIL: token consume/reserve RPC in migration"; fail=1
fi
if rg -n --glob 'src/migration/**' -e 'StrictHostKeyChecking=no' "$ROOT/src/migration" >/dev/null 2>&1; then
  echo "FAIL: StrictHostKeyChecking=no"; fail=1
fi
if rg -n --glob 'src/migration/**' -e 'nsupdate|certbot[[:space:]]+.*--dns' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never' >/dev/null 2>&1; then
  echo "FAIL: DNS mutation"; fail=1
fi
# dns_changed fields are status flags (must remain false), not mutation APIs
if rg -n --glob 'src/migration/**' -e 'dns_changed\s*=\s*True|dns_changed.: True' "$ROOT/src/migration" >/dev/null 2>&1; then
  echo "FAIL: dns_changed set true"; fail=1
fi
# Broad rsync of host roots
if rg -n --glob 'src/migration/**' -e 'rsync[[:space:]].*/(etc|home|var/lib/postgresql)' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|must not|never' >/dev/null 2>&1; then
  echo "FAIL: broad rsync host roots"; fail=1
fi
# Must refuse latest
rg -n 'latest' "$ROOT/src/migration/bootstrap/engine.sh" | grep -q 'refused\|Mutable' || {
  echo "FAIL: latest refusal missing"; fail=1
}
# Must assert no transfer (Phase 17/18 gate retained)
rg -n 'MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED|assert_no_transfer' "$ROOT/src/migration" >/dev/null || {
  echo "FAIL: transfer gate missing"; fail=1
}
# Phase 19 scoped transfer authorization must exist
rg -n 'assert_phase19_transfer_allowed|assert_no_cutover_or_token' "$ROOT/src/migration" >/dev/null || {
  echo "FAIL: Phase 19 transfer authorization helpers missing"; fail=1
}
# ops/migration.sh must remain schema remapper only
if rg -n 'migration_pair|bootstrap_code|trust_pairing' "$ROOT/src/ops/migration.sh" >/dev/null 2>&1; then
  echo "FAIL: ops/migration.sh contaminated with Phase 17 business logic"; fail=1
fi

# Secret argv patterns
if rg -n --glob 'src/migration/**' -e 'echo \$.*PASSWORD|printf.*SECRET' "$ROOT/src/migration" >/dev/null 2>&1; then
  echo "WARN: possible secret print (review)" >&2
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "phase17 static gates: PASS"
