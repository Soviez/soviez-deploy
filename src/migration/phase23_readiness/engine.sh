# shellcheck shell=bash

soviez_migration_phase23_readiness() {
  local archive_op_id="${1:-}"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_PHASE23_READINESS"
  soviez_migration_p22_paths_init
  local val report_id
  val="$(soviez_migration_phase23_readiness_validate "$archive_op_id")"
  report_id="$(soviez_migration_new_id p23r)"
  soviez_migration_phase23_readiness_write_report "$report_id" "$val"
}

soviez_migration_phase23_readiness_show() {
  local report_id="${1:-}"
  [[ -n "$report_id" ]] || soviez_migration_die MIGRATION_PHASE23_NOT_READY "report-id required"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_PHASE23_READINESS"
  soviez_migration_p22_paths_init
  local f
  f="$(soviez_migration_p22_phase23_dir "$report_id")/report.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_PHASE23_NOT_READY "report missing"
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$f")" expires_at)"; then
    soviez_migration_die MIGRATION_PHASE23_NOT_READY "phase23 readiness report expired"
  fi
  soviez_migration_phase23_readiness_drift "$f"
  cat "$f"
}
