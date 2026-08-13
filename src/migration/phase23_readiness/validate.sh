# shellcheck shell=bash

soviez_migration_phase23_readiness_validate() {
  local archive_op_id="$1"
  local blockers=() warnings=()
  local st cutover_id source_id auth_id

  st="$(soviez_migration_source_archive_status "$archive_op_id")"
  [[ "$(soviez_json_get "$st" current_state)" == "verified" ]] || blockers+=("archive_not_verified")
  cutover_id="$(soviez_json_get "$st" cutover_id)"
  source_id="$(soviez_json_get "$st" source_id)"
  auth_id="$(soviez_json_get "$st" authorization_id)"

  # Stabilization + window closed
  set +e
  soviez_migration_stabilization_latest_report "$cutover_id" >/dev/null 2>&1 || blockers+=("stabilization_missing")
  set -e
  local byc
  byc="$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
  [[ -f "$byc" ]] || blockers+=("rollback_window_open")

  # License finalized
  [[ -f "$(soviez_migration_p22_finalization_dir "$archive_op_id")/state.json" ]] || blockers+=("license_not_finalized")

  # Runtime suspended
  local sus
  sus="$(soviez_migration_p22_suspend_state_path "$source_id")"
  [[ -f "$sus" ]] || blockers+=("runtime_not_suspended")

  # Inventory
  set +e
  soviez_migration_p22_retirement_inventory_check "$source_id" >/dev/null 2>&1 || blockers+=("inventory_incomplete")
  set -e

  # Optional warnings
  if [[ "${SOVIEZ_MIG_P22_STAGE_OPTIONAL_FAIL:-0}" == "1" ]]; then
    warnings+=("optional_stage_archive")
  fi
  if [[ "${SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE:-0}" == "1" ]]; then
    warnings+=("full_erp_restore_skipped")
  fi

  # Never allow purge flags to produce PASS
  if [[ "${SOVIEZ_MIG_SOURCE_PURGE:-0}" == "1" ]]; then
    blockers+=("purge_attempted")
  fi

  local status=PASS
  if [[ ${#blockers[@]} -gt 0 ]]; then status=BLOCKED
  elif [[ ${#warnings[@]} -gt 0 ]]; then status=WARNING
  fi
  SOVIEZ_ST="$status" SOVIEZ_BL="$(printf '%s,' ${blockers[@]+"${blockers[@]}"})" \
  SOVIEZ_WN="$(printf '%s,' ${warnings[@]+"${warnings[@]}"})" \
  SOVIEZ_OP="$archive_op_id" SOVIEZ_SID="$source_id" python3 - <<'PY'
import json, os
bl=[x for x in os.environ.get("SOVIEZ_BL","").split(",") if x]
wn=[x for x in os.environ.get("SOVIEZ_WN","").split(",") if x]
print(json.dumps({
  "archive_operation_id": os.environ["SOVIEZ_OP"],
  "source_id": os.environ["SOVIEZ_SID"],
  "readiness_status": os.environ["SOVIEZ_ST"],
  "blockers": bl,
  "warnings": wn,
  "implements_offline_bundles": False,
  "implements_purge": False,
}, separators=(",", ":")))
PY
}
