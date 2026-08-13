# shellcheck shell=bash

soviez_update_paths_init() {
  : "${SOVIEZ_OPS_ROOT:?soviez_paths_init must run first}"
  SOVIEZ_UPDATE_ROOT="${SOVIEZ_UPDATE_ROOT:-$SOVIEZ_OPS_ROOT/updates}"
  SOVIEZ_UPDATE_OPS_DIR="${SOVIEZ_UPDATE_OPS_DIR:-$SOVIEZ_UPDATE_ROOT/operations}"
  SOVIEZ_UPDATE_CANDIDATES_DIR="${SOVIEZ_UPDATE_CANDIDATES_DIR:-$SOVIEZ_UPDATE_ROOT/candidates}"
  SOVIEZ_UPDATE_BACKUPS_DIR="${SOVIEZ_UPDATE_BACKUPS_DIR:-$SOVIEZ_UPDATE_ROOT/backups}"
  SOVIEZ_UPDATE_PACKAGES_DIR="${SOVIEZ_UPDATE_PACKAGES_DIR:-$SOVIEZ_UPDATE_ROOT/packages}"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    SOVIEZ_UPDATE_ROOT="$SOVIEZ_ROOT/updates"
    SOVIEZ_UPDATE_OPS_DIR="$SOVIEZ_UPDATE_ROOT/operations"
    SOVIEZ_UPDATE_CANDIDATES_DIR="$SOVIEZ_UPDATE_ROOT/candidates"
    SOVIEZ_UPDATE_BACKUPS_DIR="$SOVIEZ_UPDATE_ROOT/backups"
    SOVIEZ_UPDATE_PACKAGES_DIR="$SOVIEZ_UPDATE_ROOT/packages"
  fi
  export SOVIEZ_UPDATE_ROOT SOVIEZ_UPDATE_OPS_DIR SOVIEZ_UPDATE_CANDIDATES_DIR SOVIEZ_UPDATE_BACKUPS_DIR SOVIEZ_UPDATE_PACKAGES_DIR
  mkdir -p "$SOVIEZ_UPDATE_OPS_DIR" "$SOVIEZ_UPDATE_CANDIDATES_DIR" "$SOVIEZ_UPDATE_BACKUPS_DIR" "$SOVIEZ_UPDATE_PACKAGES_DIR"
  chmod 700 "$SOVIEZ_UPDATE_ROOT" "$SOVIEZ_UPDATE_OPS_DIR" "$SOVIEZ_UPDATE_CANDIDATES_DIR" "$SOVIEZ_UPDATE_BACKUPS_DIR" "$SOVIEZ_UPDATE_PACKAGES_DIR"
}

soviez_update_op_dir() { printf '%s/%s\n' "$SOVIEZ_UPDATE_OPS_DIR" "$1"; }
soviez_update_op_state_file() { printf '%s/state.json\n' "$(soviez_update_op_dir "$1")"; }
soviez_update_candidate_dir() { printf '%s/%s\n' "$SOVIEZ_UPDATE_CANDIDATES_DIR" "$1"; }
soviez_update_backup_dir() { printf '%s/%s\n' "$SOVIEZ_UPDATE_BACKUPS_DIR" "$1"; }
soviez_update_rollback_manifest() { printf '%s/rollback_manifest.json\n' "$(soviez_update_backup_dir "$1")"; }
