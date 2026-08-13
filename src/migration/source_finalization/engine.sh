# shellcheck shell=bash

soviez_migration_source_license_finalize() {
  local archive_op_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_LICENSE_FINALIZE"
  soviez_migration_p22_paths_init
  soviez_migration_p22_license_finalize "$archive_op_id" >/dev/null
  soviez_migration_p22_license_guard_archived "$archive_op_id" >/dev/null
  soviez_migration_p22_disable_integrations "$archive_op_id" >/dev/null
  soviez_migration_p22_credentials_disposition "$archive_op_id" >/dev/null
  soviez_migration_p22_disable_routing "$archive_op_id" >/dev/null
  soviez_migration_p22_quarantine "$archive_op_id" >/dev/null
  soviez_migration_p22_finalization_verify "$archive_op_id" >/dev/null
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/state.json"
  SOVIEZ_OUT="$out" SOVIEZ_OP="$archive_op_id" SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "archive_operation_id": os.environ["SOVIEZ_OP"],
  "current_state": "license_finalized",
  "source_license_state": "migrated_source_archived",
  "finalized_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}

soviez_migration_source_runtime_suspend() {
  local archive_op_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_RUNTIME_SUSPEND"
  soviez_migration_p22_paths_init
  # Prerequisites
  local fin
  fin="$(soviez_migration_p22_finalization_dir "$archive_op_id")/state.json"
  [[ -f "$fin" ]] || soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "license finalize required first"
  [[ -f "$(soviez_migration_p22_finalization_dir "$archive_op_id")/routing.json" ]] || \
    soviez_migration_die MIGRATION_SOURCE_PUBLIC_ROUTE_STILL_ACTIVE "routing disable required"
  [[ -f "$(soviez_migration_p22_finalization_dir "$archive_op_id")/integrations.json" ]] || \
    soviez_migration_die MIGRATION_SOURCE_INTEGRATIONS_STILL_ACTIVE "integrations disable required"
  soviez_migration_p22_runtime_suspend "$archive_op_id"
  soviez_migration_p22_postgres_optional_stop "$archive_op_id" >/dev/null
}
