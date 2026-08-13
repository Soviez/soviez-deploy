# shellcheck shell=bash

soviez_migration_p22_finalization_verify() {
  local archive_op_id="$1"
  local d
  d="$(soviez_migration_p22_finalization_dir "$archive_op_id")"
  [[ -f "$d/license.json" ]] || soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "license missing"
  [[ -f "$d/license_guard_archived.json" ]] || soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "LG missing"
  [[ -f "$d/integrations.json" ]] || soviez_migration_die MIGRATION_SOURCE_INTEGRATIONS_STILL_ACTIVE "integrations missing"
  [[ -f "$d/routing.json" ]] || soviez_migration_die MIGRATION_SOURCE_PUBLIC_ROUTE_STILL_ACTIVE "routing missing"
  [[ -f "$d/credentials.json" ]] || soviez_migration_die MIGRATION_SOURCE_CREDENTIAL_DISPOSITION_INCOMPLETE "credentials missing"
  printf '{"finalization_verified":true}\n'
}
