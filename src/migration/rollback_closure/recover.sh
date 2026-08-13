# shellcheck shell=bash

soviez_migration_rollback_window_close_recover() {
  local op_id="${1:-}"
  # Recovery is advisory — never re-opens automatic rollback silently.
  soviez_migration_rollback_window_close_status "$op_id"
}
