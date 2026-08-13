#!/usr/bin/env bash
# Phase 14 corrective — continuous canonical sync unit tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
unset SOVIEZ_OPS_SYNC_FAIL_AT 2>/dev/null || true
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p14-sync.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
soviez_ssl_paths_init 2>/dev/null || true
soviez_ops_paths_init

# --- Create + transition sync ---
op="$(soviez_op_create)"
assert_file_exists "$(soviez_ops_canonical_state_path "$op")"
assert_eq "synchronized" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" canonical_sync_status)"
assert_file_exists "$(soviez_ops_registry_index_path "$op")"

soviez_op_transition "$op" preflight
assert_eq "preflight" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" current_checkpoint)"
assert_eq "running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" current_state)"
assert_eq "preflight" "$(soviez_json_get "$(cat "$(soviez_ops_registry_index_path "$op")")" current_checkpoint)"
rev1="$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" canonical_state_revision)"

soviez_op_transition "$op" waiting_for_connection_consent
assert_eq "waiting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" current_state)"
rev2="$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" canonical_state_revision)"
[[ "$rev2" -gt "$rev1" ]] || { echo "revision did not advance" >&2; exit 1; }

# Idempotent repeated sync
soviez_ops_sync_transition "$op" new "" waiting_for_connection_consent transition "{}" "$(soviez_operation_state_file "$op")"
assert_eq "$rev2" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" canonical_state_revision)"

# --- Failure after legacy, before canonical ---
op2="$(soviez_op_create)"
soviez_op_transition "$op2" preflight
export SOVIEZ_OPS_SYNC_FAIL_AT=before_canonical
# Force a sync attempt via apply (legacy already at preflight; change checkpoint manually then sync)
soviez_json_merge_file "$(soviez_operation_state_file "$op2")" '{"state":"device_authorization_pending"}'
if soviez_ops_sync_transition "$op2" new "" device_authorization_pending transition "{}" "$(soviez_operation_state_file "$op2")"; then
  echo "expected sync failure" >&2; exit 1
fi
assert_file_exists "$(soviez_operation_dir "$op2")/sync_pending.json"
unset SOVIEZ_OPS_SYNC_FAIL_AT

# Reconcile repairs
out="$(soviez_ops_sync_reconcile "$op2")"
assert_contains "$out" OPERATION_SYNC_RECONCILED
assert_eq "synchronized" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op2")")" canonical_sync_status)"
assert_eq "device_authorization_pending" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op2")")" current_checkpoint)"

# --- Failure before registry ---
op3="$(soviez_op_create)"
soviez_op_transition "$op3" preflight
export SOVIEZ_OPS_SYNC_FAIL_AT=before_registry
soviez_json_merge_file "$(soviez_operation_state_file "$op3")" '{"state":"device_authorized"}'
if soviez_ops_sync_transition "$op3" new "" device_authorized transition "{}" "$(soviez_operation_state_file "$op3")"; then
  echo "expected registry sync failure" >&2; exit 1
fi
unset SOVIEZ_OPS_SYNC_FAIL_AT
soviez_ops_sync_reconcile "$op3" >/dev/null
assert_eq "synchronized" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op3")")" canonical_sync_status)"

# --- Conflict: sync pending blocks ---
op4="$(soviez_op_create)"
soviez_json_merge_file "$(soviez_operation_state_file "$op4")" '{"state":"running","environment_id":"stage-sync-a"}'
soviez_ops_sync_transition "$op4" retention_delete stage-sync-a running transition "{}" "$(soviez_operation_state_file "$op4")"
# Mark pending artificially
soviez_ops_sync_mark_pending "$op4" OPERATION_CANONICAL_SYNC_PENDING
# Also set incomplete on canonical
soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path "$op4")" "$(SOVIEZ_CUR="$(cat "$(soviez_ops_canonical_state_path "$op4")")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["canonical_sync_status"]="pending"; print(json.dumps(d,separators=(",",":")))
PY
)"
soviez_ops_registry_register "$op4"
if ( soviez_ops_conflict_check stage_drop stage-sync-a ) 2>/dev/null; then
  echo "pending sync must block destructive conflict" >&2; exit 1
fi
# Unrelated env still allowed
soviez_ops_conflict_check stage_drop stage-sync-b

# Clear pending and reconcile
soviez_ops_sync_reconcile "$op4" >/dev/null

# --- Stage sync ---
sop="$(soviez_stage_op_create)"
assert_file_exists "$(soviez_ops_canonical_state_path "$sop")"
soviez_stage_op_transition "$sop" preflight
assert_eq "preflight" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$sop")")" current_checkpoint)"

# --- SSL sync helper ---
ssl_op="$(soviez_ssl_renew_create_op envssl1)"
assert_eq "ssl_renewal" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$ssl_op")")" operation_type)"
soviez_ssl_op_mark "$ssl_op" waiting_for_dns envssl1
assert_eq "waiting_for_dns" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$ssl_op")")" current_checkpoint)"
assert_eq "waiting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$ssl_op")")" current_state)"

# --- Retention sync via patch ---
mkdir -p "$(soviez_stage_dir retstage)/config" "$(soviez_stage_dir retstage)/filestore" "$(soviez_stage_dir retstage)/secrets"
printf '%s\n' '{"stage_id":"retstage","created_at":"2026-08-01T12:00:00Z","stage_db_name":"db_ret","stage_filestore_path":"'"$(soviez_stage_filestore_path retstage)"'","stage_config_path":"'"$(soviez_stage_config_path retstage)"'","stage_secrets_path":"'"$(soviez_stage_secrets_path retstage)"'","stage_container":"odoo-stage-retstage","stage_network":"net","parent_production_tenant_id":"t1","license_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","lifecycle_status":"certified"}' > "$(soviez_stage_identity_file retstage)"
soviez_stage_inventory_atomic_write "$(soviez_stage_inventory_index)" '{"stages":[{"stage_id":"retstage"}]}'
soviez_retention_init_for_stage retstage "2026-08-01T12:00:00Z" >/dev/null
soviez_retention_patch retstage '{"retention_operation_id":"ret-sync-1","retention_status":"final_backup_running","state":"final_backup_running"}'
assert_file_exists "$(soviez_ops_canonical_state_path ret-sync-1)"
assert_eq "final_backup_running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path ret-sync-1)")" current_checkpoint)"
soviez_retention_patch retstage '{"retention_status":"safe_shield_validating"}'
assert_eq "safe_shield_validating" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path ret-sync-1)")" current_checkpoint)"

# Terminal
soviez_ops_sync_terminal "$op" new "" completed "$(soviez_operation_state_file "$op")"
assert_eq "completed" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" current_state)"
assert_eq "done" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" terminal_cleanup_status)"
assert_file_exists "$(soviez_ops_history_path "$op")"

# Scheduler reconcile pending does not crash
soviez_ops_scheduler_coordinate

echo "test_ops_canonical_sync: PASS"
