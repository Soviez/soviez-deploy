#!/usr/bin/env bash
# Phase 22 — archive e2e happy path through phase23 readiness
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase22_fixture.sh
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null

result="$(soviez_migration_phase22_run "$CUTOVER_OP_ID" "$SOURCE_ID")"
assert_eq "$(soviez_json_get "$result" status)" "phase22_complete" "phase22 complete"
assert_eq "$(soviez_json_get "$result" purges_source)" "False" "no purge"
op_id="$(soviez_json_get "$result" archive_operation_id)"

# Manifest flags
manifest="$(cat "$(soviez_migration_p22_archive_manifest_path "$op_id")")"
assert_eq "$(soviez_json_get "$manifest" purge_authorized)" "False" "purge_authorized false"
assert_eq "$(soviez_json_get "$manifest" deletion_performed)" "False" "deletion_performed false"

# License state
lic="$(cat "$(soviez_migration_p22_finalization_dir "$op_id")/license.json")"
assert_eq "$(soviez_json_get "$lic" source_license_state)" "migrated_source_archived" "license archived"

# Suspend state persists on disk
sus="$(cat "$(soviez_migration_p22_suspend_state_path "$SOURCE_ID")")"
assert_eq "$(soviez_json_get "$sus" suspended)" "True" "suspended"
assert_eq "$(soviez_json_get "$sus" host_preserved)" "True" "host preserved"

# Accidental start denied
set +e
( set -e; soviez_migration_p22_assert_not_accidentally_started "$SOURCE_ID" ) >/dev/null 2>/tmp/p22-accidental.err
rc=$?
set -e
[[ "$rc" -ne 0 ]]
grep -q MIGRATION_SOURCE_RUNTIME_ALREADY_SUSPENDED /tmp/p22-accidental.err

# Phase23 readiness
p23="$(soviez_json_get "$result" phase23_readiness)"
# result embeds object; re-fetch
p23="$(soviez_migration_phase23_readiness "$op_id")"
status="$(soviez_json_get "$p23" readiness_status)"
[[ "$status" == "PASS" || "$status" == "WARNING" ]]
assert_eq "$(soviez_json_get "$p23" implements_purge)" "False" "no purge product"
echo "PHASE22 HAPPY PATH — COMPLETE"

# Real pg dump + restore_test proven
db_meta="$(cat "$(soviez_migration_p22_archive_op_dir "$op_id")/database/meta.json")"
assert_eq "$(soviez_json_get "$db_meta" real_pg_dump)" "True" "real pg_dump"
rt="$(cat "$(soviez_migration_p22_archive_op_dir "$op_id")/restore_test.json")"
assert_eq "$(soviez_json_get "$rt" restore_test)" "PASS" "restore_test PASS"
assert_eq "$(soviez_json_get "$rt" real_pg_restore)" "True" "real pg_restore"
assert_eq "$(soviez_json_get "$rt" p22_archive_probe_count)" "1" "probe count=1"
echo "RESTORE TEST — REAL PG PASS"

# Source filestore file still exists (not purged)
[[ -f "$SOVIEZ_MIG_P22_SOURCE_ROOT/filestore/docs/readme.txt" ]]
echo "SOURCE DATA — RETAINED"

# Independent pinned backup still exists
[[ -n "${SOVIEZ_MIG_P22_PINNED_BACKUP:-}" && -f "$SOVIEZ_MIG_P22_PINNED_BACKUP" ]]
echo "PINNED BACKUP — RETAINED"

# Certificate revoke false / dns snapshot retained when present
cert_f="$(soviez_migration_p22_archive_op_dir "$op_id")/certificates.json"
if [[ -f "$cert_f" ]]; then
  cert="$(cat "$cert_f")"
  assert_eq "$(soviez_json_get "$cert" revoked)" "False" "certificate not revoked"
fi
dns_f="$(soviez_migration_p22_archive_op_dir "$op_id")/dns_rollback_snapshot.json"
if [[ -f "$dns_f" ]]; then
  dns="$(cat "$dns_f")"
  # retained or not deleted
  deleted="$(soviez_json_get "$dns" deleted 2>/dev/null || true)"
  if [[ -n "$deleted" && "$deleted" != "None" ]]; then
    assert_eq "$deleted" "False" "dns snapshot not deleted"
  fi
  echo "DNS SNAPSHOT — RETAINED"
fi

echo "test_phase22_archive_e2e: PASS"
