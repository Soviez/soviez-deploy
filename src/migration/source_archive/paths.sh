# shellcheck shell=bash

soviez_migration_p22_archive_op_dir() {
  [[ -n "${SOVIEZ_MIG_SOURCE_ARCHIVE_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR" "$1"
}

soviez_migration_p22_archive_plan_path() {
  printf '%s/plan.json\n' "$(soviez_migration_p22_archive_op_dir "$1")"
}

soviez_migration_p22_archive_manifest_path() {
  printf '%s/manifest.json\n' "$(soviez_migration_p22_archive_op_dir "$1")"
}

soviez_migration_p22_archive_state_path() {
  printf '%s/state.json\n' "$(soviez_migration_p22_archive_op_dir "$1")"
}
