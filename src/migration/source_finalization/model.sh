# shellcheck shell=bash

soviez_migration_p22_finalization_state_path() {
  printf '%s/%s/state.json\n' "$SOVIEZ_MIG_SOURCE_FINALIZATION_DIR" "$1"
}
