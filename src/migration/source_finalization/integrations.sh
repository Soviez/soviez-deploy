# shellcheck shell=bash

soviez_migration_p22_disable_integrations() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/integrations.json"
  mkdir -p "$(dirname "$out")"
  if [[ "${SOVIEZ_MIG_P22_INJECT_INTEGRATIONS_ACTIVE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_INTEGRATIONS_STILL_ACTIVE "integrations still active"
  fi
  printf '{"integrations_disabled":true,"webhooks":false,"payments":false,"mail":false}\n' > "$out"
  cat "$out"
}
