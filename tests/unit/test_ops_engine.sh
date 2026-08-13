#!/usr/bin/env bash
# Phase 14 — unified operation engine unit tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p14.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
soviez_ssl_paths_init 2>/dev/null || true
soviez_ops_paths_init

# --- Schema ---
rec="$(soviez_ops_new_record op-a new env-a)"
soviez_ops_validate_record "$rec"
assert_eq "1" "$(soviez_json_get "$rec" schema_version)"
assert_eq "0.15.0-phase15" "$(soviez_json_get "$rec" engine_version)"
if soviez_ops_forbid_secrets_in_json '{"password":"x"}'; then
  echo "secrets must fail" >&2; exit 1
fi

# Persist + register
mkdir -p "$(soviez_operation_dir op-a)"
soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path op-a)" "$rec"
soviez_ops_registry_register op-a
list="$(soviez_ops_registry_list)"
assert_contains "$list" op-a

# --- Transitions ---
soviez_ops_transition op-a queued
soviez_ops_transition op-a starting
soviez_ops_transition op-a running device_authorization_pending
assert_eq "running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-a)")" current_state)"
assert_eq "device_authorization_pending" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-a)")" current_checkpoint)"
soviez_ops_transition op-a completed
assert_eq "completed" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-a)")" current_state)"

rec="$(soviez_ops_new_record op-b new env-b)"
mkdir -p "$(soviez_operation_dir op-b)"
soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path op-b)" "$rec"
soviez_ops_registry_register op-b
soviez_ops_transition op-b queued
soviez_ops_transition op-b starting
soviez_ops_transition op-b running
if ( soviez_ops_transition op-b created ) 2>/dev/null; then
  echo "illegal transition allowed" >&2; exit 1
fi

# --- Locks ---
lid="$(soviez_ops_lock_id env stage-a)"
soviez_ops_lock_acquire op-b "$lid"
if ( soviez_ops_lock_acquire op-a "$lid" ) 2>/dev/null; then
  echo "same resource lock must conflict" >&2; exit 1
fi
lid2="$(soviez_ops_lock_id env stage-b)"
soviez_ops_lock_acquire op-a "$lid2"
soviez_ops_lock_release op-a "$lid2"
soviez_ops_lock_release op-b "$lid"

soviez_ops_locks_acquire_ordered op-b "$(soviez_ops_lock_id db db1)" "$(soviez_ops_lock_id env e1)"
soviez_ops_lock_release op-b "$(soviez_ops_lock_id db db1)"
soviez_ops_lock_release op-b "$(soviez_ops_lock_id env e1)"

# --- Conflicts ---
assert_eq "deny" "$(soviez_ops_conflict_decide retention_delete stage_drop stagea stagea 1)"
assert_eq "allow" "$(soviez_ops_conflict_decide ssl_renewal ssl_renewal stagea stageb 0)"
assert_eq "attach_existing" "$(soviez_ops_conflict_decide ssl_renewal ssl_renewal d1 d1 1)"
assert_eq "deny" "$(soviez_ops_conflict_decide update migrate prod prod 1)"

rec="$(soviez_ops_new_record op-ret retention_delete stagea)"
mkdir -p "$(soviez_operation_dir op-ret)"
soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path op-ret)" "$rec"
soviez_ops_registry_register op-ret
soviez_ops_transition op-ret queued
soviez_ops_transition op-ret starting
soviez_ops_transition op-ret running
if ( soviez_ops_conflict_check stage_drop stagea ) 2>/dev/null; then
  echo "retention vs drop must conflict" >&2; exit 1
fi
soviez_ops_conflict_check stage_drop stageb

# --- Cancel ---
soviez_ops_transition op-b waiting
soviez_ops_cancel op-b "test" >/dev/null
assert_eq "canceled" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-b)")" current_state)"

# --- Retry ---
rec="$(soviez_ops_new_record op-c new env-c)"
mkdir -p "$(soviez_operation_dir op-c)"
soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path op-c)" "$rec"
soviez_ops_registry_register op-c
soviez_ops_transition op-c queued
soviez_ops_transition op-c starting
soviez_ops_transition op-c failed_retryable
soviez_ops_retry op-c
assert_eq "starting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-c)")" current_state)"
assert_eq "1" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path op-c)")" retry_count)"

# --- Migration from Phase 8 legacy ---
op_id=legacy-new-1
soviez_op_create "$op_id" >/dev/null
soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" '{"state":"device_authorization_pending","kind":"new"}'
soviez_ops_migrate_legacy_new "$op_id"
canon="$(cat "$(soviez_ops_canonical_state_path "$op_id")")"
assert_eq "waiting" "$(soviez_json_get "$canon" current_state)"
assert_eq "device_authorization_pending" "$(soviez_json_get "$canon" current_checkpoint)"
assert_file_exists "$(soviez_operation_state_file "$op_id").pre-phase14.bak"
soviez_ops_migrate_legacy_new "$op_id"

# --- Heartbeat / reconcile ---
soviez_ops_heartbeat_touch "$op_id"
assert_file_exists "$(soviez_ops_heartbeat_path "$op_id")"
out="$(soviez_ops_reconcile_one "$op_id")"
case "$out" in
  healthy|attach_existing|resume_safe|recovery_required|cleanup_terminal_metadata|retry_scheduled) ;;
  *) echo "unexpected reconcile: $out" >&2; exit 1 ;;
esac

# --- Redaction in events ---
soviez_ops_append_event "$op_id" "test" 'password=supersecret'
assert_not_contains "$(cat "$(soviez_ops_events_path "$op_id")")" "supersecret"

# --- Registry filters ---
type_list="$(soviez_ops_registry_list --type new)"
assert_contains "$type_list" "legacy-new-1"

# --- Scheduler lock ---
soviez_ops_scheduler_coordinate

# --- Phase 11/12/13 migration stubs ---
mkdir -p "$SOVIEZ_STAGE_OPS_DIR/stage-op-1"
printf '%s\n' '{"operation_id":"stage-op-1","state":"database_restore","kind":"stage_create","environment_id":"stage-x"}' > "$SOVIEZ_STAGE_OPS_DIR/stage-op-1/state.json"
soviez_ops_migrate_legacy_stage stage-op-1
assert_eq "running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path stage-op-1)")" current_state)"
assert_eq "database_restore" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path stage-op-1)")" current_checkpoint)"

mkdir -p "$SOVIEZ_SSL_OPS_DIR/ssl-op-1"
printf '%s\n' '{"operation_id":"ssl-op-1","state":"waiting_for_dns","kind":"ssl_renewal","environment_id":"prod-a"}' > "$SOVIEZ_SSL_OPS_DIR/ssl-op-1/state.json"
soviez_ops_migrate_legacy_ssl ssl-op-1
assert_eq "waiting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path ssl-op-1)")" current_state)"

mkdir -p "$(dirname "$(soviez_retention_file stage-ret-env 2>/dev/null || echo "$SOVIEZ_STAGE_ROOT/inventory/stage-ret-env.retention.json")")"
# Prefer retention path helper when available
if declare -F soviez_retention_file >/dev/null 2>&1; then
  rf="$(soviez_retention_file stage-ret-env)"
  mkdir -p "$(dirname "$rf")"
  printf '%s\n' '{"retention_operation_id":"ret-op-1","state":"final_backup","environment_id":"stage-ret-env"}' > "$rf"
  soviez_ops_migrate_legacy_retention stage-ret-env
  assert_eq "running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path ret-op-1)")" current_state)"
fi

echo "test_ops_engine_unit: PASS"
