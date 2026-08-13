#!/usr/bin/env bash
# Phase 18 — static gate: no source mutation patterns in migration domain modules
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail=0
scan_forbidden() {
  local pat="$1"
  local label="$2"
  if rg -n "$pat" "$ROOT/src/migration/domain" "$ROOT/src/migration/dns" \
      "$ROOT/src/migration/landing" "$ROOT/src/migration/tls" "$ROOT/src/migration/routing" \
      2>/dev/null | grep -v '^\s*#' | grep -v 'forbidden' | grep -v 'denied' | grep -v 'assert_no' | grep -v 'die MIGRATION' >/dev/null; then
    echo "FORBIDDEN ($label): $pat" >&2
    rg -n "$pat" "$ROOT/src/migration/domain" "$ROOT/src/migration/dns" \
      "$ROOT/src/migration/landing" "$ROOT/src/migration/tls" "$ROOT/src/migration/routing" 2>/dev/null \
      | grep -v 'forbidden' | grep -v 'denied' | grep -v 'assert_no' | grep -v 'die MIGRATION' || true
    fail=1
  fi
}

scan_forbidden 'pg_dump' 'pg_dump'
scan_forbidden 'begin_license_migration' 'license migration consume'
scan_forbidden 'source_maintenance_enabled=true' 'source maintenance enable'
scan_forbidden 'destination_production_activated=true' 'production activation'
scan_forbidden 'dns_changed=true' 'production dns cutover flag'

# Source nginx write patterns (must not appear as operations)
if rg -n 'soviez_nginx_promote_owned|/etc/nginx/sites-enabled' \
  "$ROOT/src/migration/domain" "$ROOT/src/migration/dns" "$ROOT/src/migration/landing" \
  "$ROOT/src/migration/tls" "$ROOT/src/migration/routing" 2>/dev/null \
  | grep -v 'forbidden' | grep -v 'source nginx write forbidden' >/dev/null; then
  echo "FORBIDDEN: source nginx mutation references" >&2
  fail=1
fi

# Positive: guards exist
grep -q 'soviez_migration_routing_assert_no_source_mutation' "$ROOT/src/migration/routing/source_guard.sh"
grep -q 'soviez_migration_assert_no_transfer' "$ROOT/src/migration/domain/engine.sh"

[[ $fail -eq 0 ]] || exit 1
echo "PASS test_phase18_no_source_mutation"
