# shellcheck shell=bash

soviez_migration_discovery_state_write() {
  local op_id="$1" state="$2" checkpoint="${3:-}" extra="${4:-"{}"}"
  local dir sf
  soviez_migration_paths_init
  dir="$SOVIEZ_MIG_ROOT/ops/$op_id"
  mkdir -p "$dir"
  sf="$dir/state.json"
  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" SOVIEZ_EX="$extra" \
  SOVIEZ_NOW="$(soviez_migration_now_iso)" SOVIEZ_OT="$SOVIEZ_MIG_OP_DISCOVERY" python3 - <<'PY' > "$sf"
import json, os
ex = json.loads(os.environ.get("SOVIEZ_EX") or "{}")
doc = {
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": os.environ["SOVIEZ_OT"],
  "current_state": os.environ["SOVIEZ_ST"],
  "checkpoint": os.environ.get("SOVIEZ_CP") or "",
  "updated_at": os.environ["SOVIEZ_NOW"],
  "data_transfer_started": False,
  "migration_token_consumed": False,
  "source_maintenance_enabled": False,
  "destination_production_activated": False,
}
doc.update(ex)
print(json.dumps(doc, separators=(",", ":")))
PY
  local env_id
  env_id="$(soviez_json_get "$(cat "$sf")" environment_id 2>/dev/null || true)"
  if declare -F soviez_ops_sync_apply >/dev/null 2>&1; then
    soviez_ops_sync_apply "$op_id" "$SOVIEZ_MIG_OP_DISCOVERY" "$env_id" "$checkpoint" "transition" "$extra" "$sf" 2>/dev/null || true
  fi
}

soviez_migration_discover_run() {
  local target="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local prod
  prod="$(soviez_migration_resolve_production "$target")" || exit $?
  local env_id
  env_id="$(soviez_json_get "$prod" tenant_id 2>/dev/null || true)"
  [[ -z "$env_id" ]] && env_id="$(soviez_json_get "$prod" environment_id)"

  if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
    if declare -F soviez_ops_paths_init >/dev/null 2>&1; then
      soviez_ops_paths_init 2>/dev/null || true
    fi
    if [[ -n "${SOVIEZ_OPS_INDEX_DIR:-}" ]]; then
      soviez_ops_conflict_check "$SOVIEZ_MIG_OP_DISCOVERY" "$env_id" "env:$env_id" \
        || soviez_migration_die MIGRATION_ACTIVE_OPERATION_CONFLICT "Conflicting operation"
    fi
  fi

  local op_id discovery_id
  op_id="$(soviez_migration_new_id disc-op)"
  discovery_id="$(soviez_migration_new_id disc)"
  mkdir -p "$(soviez_migration_discovery_dir "$discovery_id")"
  printf '%s' "$prod" > "$(soviez_migration_discovery_dir "$discovery_id")/production.json"
  mkdir -p "$SOVIEZ_MIG_ROOT/productions/$env_id"
  printf '%s' "$prod" > "$SOVIEZ_MIG_ROOT/productions/$env_id/identity.json"

  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" "$SOVIEZ_MIG_OP_DISCOVERY" "$env_id" "env:$env_id" 2>/dev/null || true
  fi
  if declare -F soviez_ops_lock_acquire >/dev/null 2>&1; then
    soviez_ops_lock_acquire "$env_id" "$op_id" "$SOVIEZ_MIG_OP_DISCOVERY" 2>/dev/null || true
  fi

  soviez_migration_discovery_state_write "$op_id" validating_source validating_source \
    "{\"environment_id\":\"$env_id\",\"discovery_id\":\"$discovery_id\"}"

  local identity capacity runtime addons stages backup network
  soviez_migration_discovery_state_write "$op_id" collecting_identity collecting_identity "{}"
  identity="$(soviez_migration_discovery_collect_identity "$prod")"

  # Identity mismatch guard
  local got
  got="$(soviez_json_get "$identity" production_id)"
  [[ "$got" == "$env_id" ]] || soviez_migration_die MIGRATION_SOURCE_IDENTITY_MISMATCH "Identity mismatch"

  soviez_migration_discovery_state_write "$op_id" collecting_runtime collecting_runtime "{}"
  runtime="$(soviez_migration_discovery_collect_runtime "$prod")"
  # Assert source not forced into maintenance by discovery
  [[ "$(soviez_json_get "$runtime" maintenance_enabled)" != "true" ]] || \
    soviez_migration_die MIGRATION_SOURCE_INVALID "Discovery must not observe forced maintenance from itself"

  soviez_migration_discovery_state_write "$op_id" collecting_capacity collecting_capacity "{}"
  capacity="$(soviez_migration_discovery_collect_capacity "$prod")"

  soviez_migration_discovery_state_write "$op_id" collecting_addon_inventory collecting_addon_inventory "{}"
  addons="$(soviez_migration_discovery_collect_addons "$prod")"

  soviez_migration_discovery_state_write "$op_id" collecting_stage_inventory collecting_stage_inventory "{}"
  stages="$(soviez_migration_discovery_collect_stages "$prod")"

  backup="$(soviez_migration_discovery_collect_backup)"
  soviez_migration_discovery_state_write "$op_id" collecting_network_readiness collecting_network_readiness "{}"
  network="$(soviez_migration_discovery_collect_network)"

  soviez_migration_discovery_state_write "$op_id" writing_discovery_report writing_discovery_report "{}"

  local expires report
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_DISCOVERY_TTL_SECONDS:-86400}")"
  report="$(SOVIEZ_ID="$discovery_id" SOVIEZ_OP="$op_id" SOVIEZ_EX="$expires" \
    SOVIEZ_I="$identity" SOVIEZ_C="$capacity" SOVIEZ_R="$runtime" SOVIEZ_A="$addons" \
    SOVIEZ_S="$stages" SOVIEZ_B="$backup" SOVIEZ_N="$network" python3 - <<'PY'
import json, os, datetime
doc = {
  "schema_version": "soviez.migration.discovery.v1",
  "discovery_id": os.environ["SOVIEZ_ID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_EX"],
  "identity": json.loads(os.environ["SOVIEZ_I"]),
  "capacity": json.loads(os.environ["SOVIEZ_C"]),
  "runtime": json.loads(os.environ["SOVIEZ_R"]),
  "addons": json.loads(os.environ["SOVIEZ_A"]),
  "stages": json.loads(os.environ["SOVIEZ_S"]),
  "backup": json.loads(os.environ["SOVIEZ_B"]),
  "network": json.loads(os.environ["SOVIEZ_N"]),
  "data_transfer_started": False,
  "migration_token_consumed": False,
  "source_maintenance_enabled": False,
  "status": "completed",
}
print(json.dumps(doc, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store discovery "$discovery_id" "$report" >/dev/null
  soviez_migration_discovery_state_write "$op_id" completed completed \
    "{\"environment_id\":\"$env_id\",\"discovery_id\":\"$discovery_id\"}"

  if declare -F soviez_ops_lock_release >/dev/null 2>&1; then
    soviez_ops_lock_release "$env_id" "$op_id" 2>/dev/null || true
  fi

  cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json"
  soviez_migration_outcome_banner "COMPLETE" "N/A" "N/A" "N/A" >&2 || true
}

soviez_migration_discovery_show() {
  local discovery_id="${1:-}"
  [[ -n "$discovery_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "discovery-id required"
  local path
  path="$(soviez_migration_discovery_dir "$discovery_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown discovery: $discovery_id"
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Discovery report signature invalid"
  fi
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$path")" expires_at)"; then
    soviez_migration_die MIGRATION_READINESS_EXPIRED "Discovery report expired"
  fi
  cat "$path"
}
