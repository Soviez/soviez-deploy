# shellcheck shell=bash

soviez_migration_routing_source_guard() {
  soviez_migration_die MIGRATION_SOURCE_DISRUPTION_DETECTED "Source mutation forbidden in Phase 18"
}

soviez_migration_routing_assert_no_source_mutation() {
  if [[ "${SOVIEZ_MIG_SOURCE_MUTATION:-0}" == "1" ]]; then
    soviez_migration_routing_source_guard
  fi
}

soviez_migration_routing_assert_no_source_nginx_write() {
  if [[ "${SOVIEZ_MIG_SOURCE_NGINX_WRITE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_DISRUPTION_DETECTED "Source nginx write forbidden"
  fi
}

soviez_migration_routing_assert_no_db_dump_transfer() {
  if [[ "${SOVIEZ_MIG_ALLOW_DB_DUMP_TRANSFER:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED "database dump transfer forbidden in Phase 18"
  fi
}
