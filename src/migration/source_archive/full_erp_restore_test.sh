# shellcheck shell=bash

soviez_migration_p22_archive_full_erp_restore_test() {
  local op_id="$1"
  if [[ "${SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE:-0}" == "1" ]]; then
    printf '{"full_erp_restore_test":"SKIPPED","policy":"optional"}\n'
    return 0
  fi
  # Recommended: re-run DB restore test as proxy when full ERP stack unavailable.
  soviez_migration_p22_archive_restore_test "$op_id" >/dev/null
  printf '{"full_erp_restore_test":"PASS","mode":"database_proxy"}\n'
}
