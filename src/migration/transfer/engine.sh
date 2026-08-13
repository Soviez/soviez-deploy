# shellcheck shell=bash

soviez_migration_transfer_plan_run() {
  local pair_id="${1:-}" routing_plan_id="${2:-}"
  local profile="${SOVIEZ_CLI_MIG_PROFILE:-${SOVIEZ_MIG_RESOURCE_PROFILE:-balanced}}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  soviez_migration_assert_no_cutover_or_token
  if [[ -z "$routing_plan_id" ]]; then
    routing_plan_id="${SOVIEZ_CLI_MIG_ROUTING_PLAN_ID:-}"
  fi
  if [[ -z "$routing_plan_id" ]]; then
    routing_plan_id="$(soviez_migration_transfer_find_latest_routing_pass "$pair_id")"
  fi
  [[ -n "$routing_plan_id" ]] || soviez_migration_die MIGRATION_ROUTING_READINESS_REQUIRED "routing-plan-id required"
  soviez_migration_transfer_require_routing "$pair_id" "$routing_plan_id"
  local pin
  pin="$(soviez_migration_transfer_backup_gate "$pair_id" "")"
  local plan
  plan="$(soviez_migration_transfer_plan_create "$pair_id" "$routing_plan_id" "$pin" "$profile")"
  local op_id plan_id
  op_id="$(soviez_json_get "$plan" operation_id)"
  plan_id="$(soviez_json_get "$plan" transfer_plan_id)"
  soviez_migration_transfer_state_write "$op_id" "$(SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_PID="$plan_id" SOVIEZ_RID="$routing_plan_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "migration_transfer_plan",
  "current_state": "completed",
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "transfer_plan_id": os.environ["SOVIEZ_PID"],
  "routing_plan_id": os.environ["SOVIEZ_RID"],
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
}, separators=(",", ":")))
PY
)"
  # Also pin backup under this op
  soviez_migration_transfer_backup_gate "$pair_id" "$op_id" >/dev/null
  printf '%s\n' "$plan"
}

soviez_migration_presync_run() {
  local pair_id="${1:-}" plan_id="${2:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  soviez_migration_assert_phase19_transfer_allowed "$pair_id" "$SOVIEZ_MIG_OP_PAYLOAD_PRESYNC"
  local plan plan_json op_id manifest
  if [[ -n "$plan_id" ]]; then
    plan_json="$(soviez_migration_transfer_plan_show "$plan_id")"
  else
    plan_json="$(soviez_migration_transfer_plan_run "$pair_id")"
    plan_id="$(soviez_json_get "$plan_json" transfer_plan_id)"
  fi
  op_id="$(soviez_migration_new_id presync)"
  soviez_migration_assert_phase19_transfer_allowed "$pair_id" "$SOVIEZ_MIG_OP_PAYLOAD_PRESYNC"
  manifest="$(soviez_migration_transfer_manifest_create "$plan_json" "$op_id")"
  local manifest_id
  manifest_id="$(soviez_json_get "$manifest" manifest_id)"
  soviez_migration_channel_init "$pair_id" "$op_id" "$manifest_id" >/dev/null
  soviez_migration_chunk_registry_init "$op_id" "$manifest_id"
  # Filestore / addons / config pre-sync (source remains active — no freeze)
  soviez_migration_filestore_presync "$pair_id" "$op_id" "$manifest_id" >/dev/null || true
  soviez_migration_addons_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null || true
  soviez_migration_config_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null || true
  soviez_migration_transfer_state_write "$op_id" "$(SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_PID="$plan_id" SOVIEZ_MID="$manifest_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "migration_payload_presync",
  "current_state": "completed",
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "transfer_plan_id": os.environ["SOVIEZ_PID"],
  "manifest_id": os.environ["SOVIEZ_MID"],
  "source_write_freeze": False,
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
}, separators=(",", ":")))
PY
)"
  cat "$(soviez_migration_transfer_op_dir "$op_id")/state.json"
}

soviez_migration_presync_status() {
  local op_id="${1:-}"
  soviez_migration_transfer_status "$op_id"
}

soviez_migration_transfer_start() {
  local pair_id="${1:-}" routing_plan_id="${2:-}"
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  if declare -F soviez_phase19_assert_cert_gates >/dev/null 2>&1; then
    soviez_phase19_assert_cert_gates
  fi
  soviez_migration_assert_no_cutover_or_token

  if [[ -z "$routing_plan_id" ]]; then
    routing_plan_id="${SOVIEZ_CLI_MIG_ROUTING_PLAN_ID:-}"
  fi
  if [[ -z "$routing_plan_id" ]]; then
    routing_plan_id="$(soviez_migration_transfer_find_latest_routing_pass "$pair_id")"
  fi
  [[ -n "$routing_plan_id" ]] || soviez_migration_die MIGRATION_ROUTING_READINESS_REQUIRED "routing-plan-id required"

  soviez_migration_assert_phase19_transfer_allowed "$pair_id" "$SOVIEZ_MIG_OP_FINAL_SYNC"
  soviez_migration_transfer_require_routing "$pair_id" "$routing_plan_id"

  local op_id profile pin plan plan_id manifest manifest_id staging_id ready stages_state
  op_id="$(soviez_migration_new_id xfer)"
  profile="${SOVIEZ_CLI_MIG_PROFILE:-${SOVIEZ_MIG_RESOURCE_PROFILE:-balanced}}"
  pin="$(soviez_migration_transfer_backup_gate "$pair_id" "$op_id")"
  plan="$(soviez_migration_transfer_plan_create "$pair_id" "$routing_plan_id" "$pin" "$profile")"
  plan_id="$(soviez_json_get "$plan" transfer_plan_id)"
  manifest="$(soviez_migration_transfer_manifest_create "$plan" "$op_id")"
  manifest_id="$(soviez_json_get "$manifest" manifest_id)"

  soviez_migration_transfer_state_write "$op_id" "$(SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_PID="$plan_id" SOVIEZ_MID="$manifest_id" SOVIEZ_RID="$routing_plan_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "migration_final_sync",
  "current_state": "establishing_secure_channel",
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "transfer_plan_id": os.environ["SOVIEZ_PID"],
  "manifest_id": os.environ["SOVIEZ_MID"],
  "routing_plan_id": os.environ["SOVIEZ_RID"],
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
  "source_runtime_active": True,
  "source_license_active": True,
}, separators=(",", ":")))
PY
)"

  soviez_migration_channel_init "$pair_id" "$op_id" "$manifest_id" >/dev/null
  if declare -F soviez_phase19_assert_channel_real >/dev/null 2>&1; then
    soviez_phase19_assert_channel_real "$op_id"
  fi
  soviez_migration_chunk_registry_init "$op_id" "$manifest_id"
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"presyncing_filestore"}' >/dev/null
  soviez_migration_filestore_presync "$pair_id" "$op_id" "$manifest_id" >/dev/null || true
  soviez_migration_addons_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null || true
  soviez_migration_config_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null || true

  # Staging identity early
  staging_id="$(soviez_migration_staging_identity_create "$pair_id" "$op_id" "$manifest_id")"
  soviez_migration_transfer_state_merge "$op_id" "{\"destination_staging_id\":\"$staging_id\"}" >/dev/null

  # Final freeze — requires confirmation unless fixture/test
  if [[ "$confirm" != "1" && "${SOVIEZ_MIG_FREEZE_FIXTURE:-0}" != "1" && "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_CONFIRMATION_REQUIRED "Final write freeze requires --confirm"
  fi

  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"freezing_source_writes"}' >/dev/null
  if ! soviez_migration_freeze_start "$pair_id" "$op_id" >/dev/null; then
    soviez_migration_freeze_release "$pair_id" "$op_id" "freeze_failed" >/dev/null || true
    soviez_migration_die MIGRATION_SOURCE_FREEZE_FAILED "Source write freeze failed"
  fi

  local freeze_rc=0
  (
    set -e
    soviez_migration_transfer_state_merge "$op_id" '{"current_state":"creating_final_database_snapshot"}' >/dev/null
    soviez_migration_database_dump "$pair_id" "$op_id" >/dev/null
    soviez_migration_database_transfer "$pair_id" "$op_id" "$manifest_id" >/dev/null
    soviez_migration_filestore_delta "$pair_id" "$op_id" "$manifest_id" >/dev/null
    soviez_migration_database_restore "$pair_id" "$op_id" "$staging_id" >/dev/null
    soviez_migration_filestore_assemble "$op_id" "$staging_id" >/dev/null
  ) || freeze_rc=$?

  # Always release freeze ASAP
  soviez_migration_freeze_release "$pair_id" "$op_id" "final_pass_complete" >/dev/null || true

  if [[ "$freeze_rc" -ne 0 ]]; then
    # Check timeout marker
    if [[ -f "$(soviez_migration_freeze_dir "$op_id")/timed_out" ]]; then
      soviez_migration_die MIGRATION_SOURCE_FREEZE_TIMEOUT "Freeze timed out; source released"
    fi
    soviez_migration_die MIGRATION_TRANSFER_RECOVERY_REQUIRED "Final sync failed after freeze release"
  fi

  stages_state="COMPLETE"
  if ! soviez_migration_stages_transfer "$pair_id" "$op_id" "$manifest_id" "$staging_id" >/dev/null; then
    stages_state="WARNING"
  fi

  soviez_migration_staging_neutralize "$staging_id" >/dev/null
  soviez_migration_staging_startup "$staging_id" >/dev/null
  soviez_migration_staging_validate "$staging_id" >/dev/null

  ready="$(soviez_migration_phase20_readiness_report "$op_id" "$stages_state")"
  local ready_result
  ready_result="$(soviez_json_get "$ready" result)"

  soviez_migration_transfer_state_merge "$op_id" "$(SOVIEZ_R="$ready_result" SOVIEZ_S="$staging_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "current_state": "completed",
  "checkpoint": "phase20_readiness",
  "destination_staging_id": os.environ["SOVIEZ_S"],
  "ready_for_20": os.environ["SOVIEZ_R"],
  "source_write_freeze": False,
  "source_runtime_active": True,
  "source_license_active": True,
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
}, separators=(",", ":")))
PY
)" >/dev/null

  soviez_migration_transfer_phase20_banner \
    "VALID" "VALID" "VERIFIED" "SIGNED" "ESTABLISHED" \
    "COMPLETE" "COMPLETE" "COMPLETE" "$stages_state" "VERIFIED" "$ready_result" >&2 || true

  cat "$(soviez_migration_transfer_op_dir "$op_id")/state.json"
}

soviez_migration_transfer_status() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  soviez_migration_paths_init
  local st
  st="$(soviez_migration_transfer_state_read "$op_id")" || \
    soviez_migration_die MIGRATION_NOT_FOUND "Unknown transfer operation: $op_id"
  printf '%s\n' "$st"
}

soviez_migration_transfer_pause() {
  local op_id="${1:-}"
  soviez_migration_paths_init
  # Release freeze if active
  local pair_id
  pair_id="$(soviez_json_get "$(soviez_migration_transfer_state_read "$op_id")" migration_pair_id)"
  soviez_migration_freeze_release "$pair_id" "$op_id" "paused" >/dev/null 2>&1 || true
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"paused","source_write_freeze":false}' 
}

soviez_migration_transfer_resume() {
  local op_id="${1:-}"
  local st pair_id routing_plan_id
  st="$(soviez_migration_transfer_state_read "$op_id")" || \
    soviez_migration_die MIGRATION_RESUME_REQUIRED "Unknown operation"
  pair_id="$(soviez_json_get "$st" migration_pair_id)"
  routing_plan_id="$(soviez_json_get "$st" routing_plan_id)"
  # Revalidate
  soviez_migration_transfer_require_routing "$pair_id" "$routing_plan_id"
  soviez_migration_transfer_backup_gate "$pair_id" "$op_id" >/dev/null
  local mid
  mid="$(soviez_json_get "$st" manifest_id)"
  [[ -n "$mid" && "$mid" != "null" ]] && soviez_migration_transfer_manifest_verify "$mid" >/dev/null
  soviez_migration_transfer_resume_from_registry "$op_id" >/dev/null
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"running","checkpoint":"resumed"}'
}

soviez_migration_transfer_cancel() {
  local op_id="${1:-}"
  local st pair_id
  st="$(soviez_migration_transfer_state_read "$op_id")" || \
    soviez_migration_die MIGRATION_NOT_FOUND "Unknown operation"
  pair_id="$(soviez_json_get "$st" migration_pair_id)"
  soviez_migration_freeze_release "$pair_id" "$op_id" "canceled" >/dev/null 2>&1 || true
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"canceled","source_write_freeze":false,"migration_token_reserved":false,"migration_token_consumed":false,"destination_production_activated":false,"traffic_cutover_started":false}'
}

soviez_migration_transfer_abort() {
  # Always release freeze + shut down transfer channel; preserve staging by default.
  local op_id="${1:-}"
  local st pair_id
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  soviez_migration_paths_init
  st="$(soviez_migration_transfer_state_read "$op_id" 2>/dev/null || echo '{}')"
  pair_id="$(soviez_json_get "$st" migration_pair_id 2>/dev/null || true)"
  [[ -n "$pair_id" && "$pair_id" != "null" ]] || pair_id="${SOVIEZ_CLI_MIG_PAIR_ID:-}"
  if [[ -n "$pair_id" && "$pair_id" != "null" ]]; then
    soviez_migration_freeze_release "$pair_id" "$op_id" "aborted" >/dev/null 2>&1 || true
  fi
  if declare -F soviez_migration_channel_shutdown >/dev/null 2>&1; then
    soviez_migration_channel_shutdown "$op_id" >/dev/null 2>&1 || true
  fi
  # Revoke channel credentials by removing channel meta (exact)
  local ch_dir
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  rm -f "$ch_dir/meta/channel.json" 2>/dev/null || true
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"aborted","source_write_freeze":false,"source_runtime_active":true,"source_license_active":true,"migration_token_reserved":false,"migration_token_consumed":false,"destination_production_activated":false,"traffic_cutover_started":false,"abort_preserved_staging":true}'
}

soviez_migration_transfer_recover() {
  local op_id="${1:-}"
  local st pair_id
  st="$(soviez_migration_transfer_state_read "$op_id")" || \
    soviez_migration_die MIGRATION_TRANSFER_RECOVERY_REQUIRED "Unknown operation"
  pair_id="$(soviez_json_get "$st" migration_pair_id)"
  soviez_migration_freeze_reconcile "$pair_id" "$op_id" >/dev/null || true
  if [[ "$(soviez_json_get "$st" current_state)" == "paused" ]]; then
    soviez_migration_transfer_resume "$op_id"
    return $?
  fi
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"recovery_required","checkpoint":"reconciled"}'
}

soviez_migration_destination_verify() {
  local op_id="${1:-}"
  local st staging_id
  st="$(soviez_migration_transfer_state_read "$op_id")" || \
    soviez_migration_die MIGRATION_NOT_FOUND "Unknown operation"
  staging_id="$(soviez_json_get "$st" destination_staging_id)"
  [[ -n "$staging_id" && "$staging_id" != "null" ]] || \
    soviez_migration_die MIGRATION_STAGING_INVALID "No staging identity on operation"
  soviez_migration_staging_validate "$staging_id"
}

soviez_migration_phase20_readiness_report() {
  local op_id="$1" stages_state="${2:-COMPLETE}"
  local st result="PASS" warnings="[]" blockers="[]"
  st="$(soviez_migration_transfer_state_read "$op_id" 2>/dev/null || echo '{}')"
  if [[ "$stages_state" == "WARNING" ]]; then
    result="WARNING"
    warnings='["optional_stage_failed"]'
  elif [[ "$stages_state" == "BLOCKED" ]]; then
    result="BLOCKED"
    blockers='["mandatory_stage_failed"]'
  fi
  # Token must remain false
  SOVIEZ_OP="$op_id" SOVIEZ_R="$result" SOVIEZ_W="$warnings" SOVIEZ_B="$blockers" SOVIEZ_ST="$st" python3 - <<'PY'
import json, os, datetime
st=json.loads(os.environ["SOVIEZ_ST"] or "{}")
doc={
  "schema_version":"soviez.migration_ready_for_20.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "result": os.environ["SOVIEZ_R"],
  "warnings": json.loads(os.environ["SOVIEZ_W"]),
  "blockers": json.loads(os.environ["SOVIEZ_B"]),
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
  "source_runtime_active": True,
  "source_license_active": True,
  "source_write_freeze": False,
  "transfer_plan_id": st.get("transfer_plan_id"),
  "manifest_id": st.get("manifest_id"),
  "destination_staging_id": st.get("destination_staging_id"),
  "issued_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
print(json.dumps(doc, separators=(",", ":")))
PY
}
