# shellcheck shell=bash

soviez_migration_p22_archive_report() {
  local op_id="$1"
  local f
  f="$(soviez_migration_p22_archive_op_dir "$op_id")/report.json"
  if [[ -f "$f" ]]; then cat "$f"; return 0; fi
  soviez_migration_source_archive_status "$op_id"
}
