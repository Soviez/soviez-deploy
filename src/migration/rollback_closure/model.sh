# shellcheck shell=bash

soviez_migration_p22_closure_receipt_path() {
  printf '%s/receipt.json\n' "$(soviez_migration_p22_closure_dir "$1")"
}

soviez_migration_p22_closure_by_cutover_path() {
  [[ -n "${SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/by_cutover/%s.json\n' "$SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR" "$1"
}
