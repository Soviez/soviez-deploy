#!/usr/bin/env bash
# Phase 14 corrective — continuous sync freshness across families (disposable).
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
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p14-sync-e2e.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
soviez_ssl_paths_init
soviez_ops_paths_init

# Phase 8 path: each transition immediately visible in registry (no migrate-on-read)
op="$(soviez_op_create)"
for st in preflight waiting_for_connection_consent device_authorization_pending; do
  soviez_op_transition "$op" "$st"
  assert_eq "$st" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" current_checkpoint)"
  assert_eq "$st" "$(soviez_json_get "$(cat "$(soviez_ops_registry_index_path "$op")")" current_checkpoint)"
  assert_eq "synchronized" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op")")" canonical_sync_status)"
done
# Status without migrate
rm -f "$(soviez_operation_dir "$op")/sync_pending.json"
status="$(soviez_ops_print_status "$op")"
assert_contains "$status" device_authorization_pending

# Interrupt dual-write then reconcile
export SOVIEZ_OPS_SYNC_FAIL_AT=before_canonical
soviez_json_merge_file "$(soviez_operation_state_file "$op")" '{"state":"device_authorized"}'
soviez_ops_sync_transition "$op" new "" device_authorized transition "{}" "$(soviez_operation_state_file "$op")" || true
unset SOVIEZ_OPS_SYNC_FAIL_AT
assert_file_exists "$(soviez_operation_dir "$op")/sync_pending.json"
# Conflict engine fail-closed while pending on same env
soviez_json_merge_file "$(soviez_ops_canonical_state_path "$op")" "$(SOVIEZ_CUR="$(cat "$(soviez_ops_canonical_state_path "$op")")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_CUR"]); d["environment_id"]="env-x"; d["canonical_sync_status"]="pending"; d["operation_type"]="retention_delete"; d["current_state"]="running"
print(json.dumps(d,separators=(",",":")))
PY
)"
soviez_ops_registry_register "$op"
if ( soviez_ops_conflict_check stage_drop env-x ) 2>/dev/null; then
  echo "stale sync must deny" >&2; exit 1
fi
soviez_ops_sync_reconcile "$op" >/dev/null

# Stage continuous sync
sop="$(soviez_stage_op_create)"
soviez_stage_op_transition "$sop" preflight
assert_eq "preflight" "$(soviez_json_get "$(cat "$(soviez_ops_registry_index_path "$sop")")" current_checkpoint)"

# SSL continuous sync
ssl="$(soviez_ssl_renew_create_op e1)"
soviez_ssl_op_mark "$ssl" waiting_for_dns e1
soviez_ssl_op_mark "$ssl" certificate_promoting e1
assert_eq "certificate_promoting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$ssl")")" current_checkpoint)"
soviez_ops_sync_terminal "$ssl" ssl_renewal e1 completed "$(soviez_operation_state_file "$ssl")"
assert_eq "completed" "$(soviez_json_get "$(cat "$(soviez_ops_registry_index_path "$ssl")")" current_state)"
assert_eq "done" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$ssl")")" terminal_cleanup_status)"

# Retention continuous sync + no destructive replay on reconcile
mkdir -p "$(soviez_stage_dir rs)/config" "$(soviez_stage_dir rs)/filestore"
printf '%s\n' rs > "$(soviez_stage_dir rs)/config/nginx.owned"
soviez_stage_inventory_atomic_write "$(soviez_stage_identity_file rs)" '{"stage_id":"rs","created_at":"2026-08-01T12:00:00Z","stage_db_name":"db_rs","stage_filestore_path":"'"$(soviez_stage_filestore_path rs)"'","stage_config_path":"'"$(soviez_stage_config_path rs)"'","stage_secrets_path":"'"$(soviez_stage_dir rs)"'/secrets","stage_container":"odoo-stage-rs","stage_network":"n","parent_production_tenant_id":"t","license_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","lifecycle_status":"certified"}'
soviez_stage_inventory_atomic_write "$(soviez_stage_inventory_index)" '{"stages":[{"stage_id":"rs"}]}'
soviez_retention_init_for_stage rs "2026-08-01T12:00:00Z" >/dev/null
soviez_retention_patch rs '{"retention_operation_id":"ret-e2e-1","retention_status":"final_backup_running"}'
soviez_retention_patch rs '{"retention_status":"deletion_running","completed_deletion_steps":["final_backup","stop_container"]}'
# Crash marker after destructive checkpoint
export SOVIEZ_OPS_SYNC_FAIL_AT=before_registry
soviez_retention_patch rs '{"retention_status":"deletion_running","completed_deletion_steps":["final_backup","stop_container","remove_nginx"]}' || true
unset SOVIEZ_OPS_SYNC_FAIL_AT
# Reconcile must restore canonical to legacy without replaying deletes
soviez_ops_sync_reconcile ret-e2e-1 >/dev/null
assert_eq "deletion_running" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path ret-e2e-1)")" current_checkpoint)"
steps="$(soviez_json_get "$(soviez_retention_read rs)" completed_deletion_steps)"
assert_contains "$steps" remove_nginx

echo "test_ops_canonical_sync_e2e: PASS"
