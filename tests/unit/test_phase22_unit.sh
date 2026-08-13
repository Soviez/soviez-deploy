#!/usr/bin/env bash
# Phase 22 unit tests — clock, gate, confirmation, codes
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
# shellcheck source=tests/helpers/phase22_fixture.sh
source "$ROOT/tests/helpers/phase22_fixture.sh"

# Unit paths do not require live postgres / real pg_dump.
export SOVIEZ_MIG_P22_REQUIRE_REAL_PG=0
export SOVIEZ_MIG_P22_SKIP_DOCKER_PG=1
soviez_phase22_fixture_init "$ROOT"

# --- cert clock allow/deny ---
export SOVIEZ_MIG_P22_FIXTURE=1 SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK=1
export SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH=1700000000
assert_eq "$(soviez_migration_p22_now_epoch)" "1700000000" "cert clock epoch"
assert_eq "$(soviez_migration_p22_clock_source)" "certification_override" "clock source override"

unset SOVIEZ_MIG_P22_FIXTURE SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK
export SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH=1700000000
set +e
( set -e; soviez_migration_p22_now_epoch ) >/dev/null 2>/tmp/p22-clock.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_PHASE22_CERT_CLOCK_DENIED /tmp/p22-clock.err
echo "CERT CLOCK — DENIED outside fixture"

# restore fixture flags
export SOVIEZ_MIG_P22_FIXTURE=1 SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK=1
SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH="$(date -u +%s)"

# --- purge always denied ---
export SOVIEZ_MIG_P22_CANONICAL=1 SOVIEZ_MIG_SOURCE_PURGE=1
set +e
( set -e; soviez_migration_assert_phase22_allowed migration_source_archive ) >/dev/null 2>/tmp/p22-purge.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_PURGE_NOT_AUTHORIZED /tmp/p22-purge.err
unset SOVIEZ_MIG_SOURCE_PURGE
echo "PURGE — ALWAYS DENIED"

# --- canonical required ---
unset SOVIEZ_MIG_P22_CANONICAL
set +e
( set -e; SOVIEZ_MIG_P22_MUTATING=1 soviez_migration_assert_phase22_allowed migration_source_archive ) >/dev/null 2>/tmp/p22-canon.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_PHASE22_CANONICAL_REQUIRED /tmp/p22-canon.err
export SOVIEZ_MIG_P22_CANONICAL=1
echo "CANONICAL — REQUIRED"

# --- confirmation phrase ---
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW demo-cutover"
soviez_migration_rollback_window_confirm "demo-cutover"
export SOVIEZ_CLI_CONFIRM_PHRASE="WRONG"
set +e
( set -e; soviez_migration_rollback_window_confirm "demo-cutover" ) >/dev/null 2>/tmp/p22-confirm.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_PHASE22_CONFIRMATION_REQUIRED /tmp/p22-confirm.err
echo "CONFIRMATION — PHRASE ENFORCED"

# --- codes present ---
printf '%s\n' "${SOVIEZ_MIGRATION_CODES[@]}" | grep -qx MIGRATION_PHASE21_READINESS_REQUIRED
printf '%s\n' "${SOVIEZ_MIGRATION_CODES[@]}" | grep -qx MIGRATION_MANUAL_INTERVENTION_REQUIRED
printf '%s\n' "${SOVIEZ_MIGRATION_CODES[@]}" | grep -qx MIGRATION_PURGE_NOT_AUTHORIZED
echo "CODES — PRESENT"

echo "test_phase22_unit: PASS"
