#!/usr/bin/env bash
# Phase 14 — unified registry / conflict / migration integration (disposable).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p14-e2e.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
soviez_ssl_paths_init
soviez_ops_paths_init

mk_op() {
  local id="$1" type="$2" env="$3" state="${4:-running}" checkpoint="${5:-work}"
  mkdir -p "$(soviez_operation_dir "$id")"
  local rec
  rec="$(soviez_ops_new_record "$id" "$type" "$env" "$checkpoint")"
  soviez_stage_inventory_atomic_write "$(soviez_ops_canonical_state_path "$id")" "$rec"
  soviez_ops_registry_register "$id"
  case "$state" in
    created) ;;
    *)
      soviez_ops_transition "$id" queued
      soviez_ops_transition "$id" starting
      [[ "$state" == starting ]] && return 0
      soviez_ops_transition "$id" "$state" "$checkpoint"
      ;;
  esac
}

# Unified registry across types
mk_op new-1 new prod-1 running device_authorization_pending
mk_op stage-1 stage_create stage-a running database_restore
mk_op ssl-1 ssl_renewal prod-1 waiting waiting_for_dns
mk_op ret-1 retention_delete stage-a running final_backup

all="$(soviez_ops_registry_list)"
assert_contains "$all" new-1
assert_contains "$all" stage-1
assert_contains "$all" ssl-1
assert_contains "$all" ret-1

assert_contains "$(soviez_ops_registry_list --type retention_delete)" ret-1
assert_contains "$(soviez_ops_registry_list --environment stage-a)" stage-1
assert_contains "$(soviez_ops_registry_list --active)" ssl-1
active="$(soviez_ops_registry_list --active)"
# completed filter sanity: complete one and ensure --active drops it
soviez_ops_transition new-1 completed
active="$(soviez_ops_registry_list --active)"
if printf '%s' "$active" | grep -Fq '"operation_id":"new-1"'; then
  echo "completed op still active" >&2; exit 1
fi

# Cross-command conflicts
if ( soviez_ops_conflict_check stage_drop stage-a ) 2>/dev/null; then
  echo "retention must block stage drop" >&2; exit 1
fi
if ( soviez_ops_conflict_check stage_backup stage-a ) 2>/dev/null; then
  echo "retention must block backup" >&2; exit 1
fi
# Unrelated stage B allowed
soviez_ops_conflict_check stage_drop stage-b

# Same-domain SSL attach/deny semantics via decide
assert_eq "attach_existing" "$(soviez_ops_conflict_decide ssl_renewal ssl_renewal d1 d1 1)"
assert_eq "allow" "$(soviez_ops_conflict_decide ssl_renewal ssl_renewal d1 d2 0)"

# Stage A vs Stage B coexistence via locks
soviez_ops_lock_acquire stage-1 "$(soviez_ops_lock_id env stage-a)"
soviez_ops_lock_acquire ssl-1 "$(soviez_ops_lock_id env stage-b)"
soviez_ops_lock_release stage-1 "$(soviez_ops_lock_id env stage-a)"
soviez_ops_lock_release ssl-1 "$(soviez_ops_lock_id env stage-b)"

# Status / cancel / retry / recover / logs / reconcile CLI helpers
status="$(soviez_ops_print_status stage-1)"
assert_contains "$status" stage-1
assert_contains "$status" database_restore

soviez_ops_log_append ssl-1 "token=abc123secret password=hunter2"
assert_not_contains "$(soviez_ops_log_tail ssl-1)" "hunter2"
assert_not_contains "$(soviez_ops_log_tail ssl-1)" "abc123secret"

soviez_ops_transition ssl-1 cancel_requested
# waiting was state; cancel_requested from waiting is allowed
# actually ssl-1 is waiting - transition to cancel_requested then canceled via cancel API
# Reset: create fresh cancel target
mk_op cancel-me new env-z waiting waiting_for_connection_consent
# mk_op ends in waiting via transition running then... wait, mk_op goes queued->starting->waiting. Good.
soviez_ops_cancel cancel-me "e2e" >/dev/null
assert_eq "canceled" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path cancel-me)")" current_state)"

mk_op retry-me new env-r failed_retryable work
soviez_ops_retry retry-me
assert_eq "starting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path retry-me)")" current_state)"

decision="$(soviez_ops_reconcile_one stage-1)"
case "$decision" in
  healthy|attach_existing|resume_safe|recovery_required|cleanup_terminal_metadata|retry_scheduled) ;;
  *) echo "bad reconcile $decision" >&2; exit 1 ;;
esac

# Stale lock: do not steal
soviez_ops_lock_acquire ret-1 "$(soviez_ops_lock_id env stage-a)"
if ( soviez_ops_lock_acquire stage-1 "$(soviez_ops_lock_id env stage-a)" ) 2>/dev/null; then
  echo "lock stolen" >&2; exit 1
fi
soviez_ops_lock_release ret-1 "$(soviez_ops_lock_id env stage-a)"

# Legacy migration dry-run + migrate
mkdir -p "$(soviez_operation_dir legacy-p8)"
printf '%s\n' '{"operation_id":"legacy-p8","state":"manual_activation_pending","kind":"new"}' > "$(soviez_operation_state_file legacy-p8)"
dry="$(soviez_ops_migrate_all --dry-run)"
assert_contains "$dry" legacy-p8
soviez_ops_migrate_legacy_new legacy-p8
assert_eq "waiting" "$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path legacy-p8)")" current_state)"
soviez_ops_migrate_legacy_new legacy-p8

# Scheduler coordination (no crash)
soviez_ops_scheduler_coordinate

# Host-level list via command wrappers
out="$(soviez_cmd_operations_list)"
assert_contains "$out" ret-1

echo "test_ops_unified_e2e: PASS"
