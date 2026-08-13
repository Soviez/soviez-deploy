#!/usr/bin/env bash
# Phase 17 — scoped no-payload-transfer static + runtime gates
# Phase 19/22: allow pg_dump/pg_restore/rsync ONLY under authorized migration paths:
# database/, filestore/, transfer/, stages/, staging/, source_archive/. Still forbid SaaS relay,
# token burn, DNS mutation, StrictHostKeyChecking=no, broad rsync of host roots.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/tests/helpers/rg_fallback.sh" ]] || { echo "FATAL: missing rg_fallback.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
fail=0

P19_PAYLOAD_ALLOW='src/migration/database/|src/migration/filestore/|src/migration/transfer/|src/migration/stages/|src/migration/staging/|src/migration/source_archive/'

# Payload tools outside authorized Phase 19/22 paths
if rg -n -e '\bpg_dump\b|\bpg_restore\b' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE "$P19_PAYLOAD_ALLOW" \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never|database dump transfer|pg_dump -Fc' >/dev/null 2>&1; then
  echo "FAIL: pg_dump/pg_restore outside authorized migration/database|filestore|transfer|stages|staging|source_archive"; fail=1
fi

# Broad rsync of host roots still forbidden
if rg -n -e 'rsync[[:space:]].*/(etc|home|var/lib/postgresql|var/lib/docker)' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|must not|never' >/dev/null 2>&1; then
  echo "FAIL: broad rsync of host roots"; fail=1
fi
if rg -n -e '\brsync\b' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE "$P19_PAYLOAD_ALLOW" \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never|broad rsync' >/dev/null 2>&1; then
  echo "FAIL: rsync outside authorized transfer paths"; fail=1
fi

if rg -n -e 'begin_license_migration|consume_ip_migration_token|migrate_license_ip' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never|Phase 20' >/dev/null 2>&1; then
  echo "FAIL: token burn/reserve RPC"; fail=1
fi
if rg -n -e 'nsupdate|certbot[[:space:]]+.*--dns' "$ROOT/src/migration" 2>/dev/null \
  | grep -vE 'forbidden|forbids|assert_no|NOT_AUTHORIZED|die MIGRATION|must not|never' >/dev/null 2>&1; then
  echo "FAIL: DNS mutation"; fail=1
fi
if rg -n -e 'StrictHostKeyChecking=no' "$ROOT/src/migration" >/dev/null 2>&1; then
  echo "FAIL: StrictHostKeyChecking=no"; fail=1
fi
rg -n 'MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED|assert_no_transfer' "$ROOT/src/migration" >/dev/null || { echo "FAIL missing transfer gate"; fail=1; }
if rg -n 'migration_pair|bootstrap_code|trust_pairing' "$ROOT/src/ops/migration.sh" >/dev/null 2>&1; then
  echo "FAIL ops/migration.sh contaminated"; fail=1
fi
[[ "$fail" -eq 0 ]] || exit 1
echo "test_phase17_no_payload_transfer: PASS"
