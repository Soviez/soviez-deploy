# shellcheck shell=bash

soviez_backup_paths_init() {
  local root="${SOVIEZ_ROOT:-/var/soviez}"
  # Always derive from SOVIEZ_ROOT so disposable tests cannot leak prior BACKUP_ROOT
  SOVIEZ_BACKUP_ROOT="${root}/backups"
  SOVIEZ_BACKUP_INVENTORY_DIR="${SOVIEZ_BACKUP_ROOT}/inventory"
  SOVIEZ_BACKUP_OPS_DIR="${SOVIEZ_BACKUP_ROOT}/operations"
  SOVIEZ_BACKUP_DEST_DIR="${SOVIEZ_BACKUP_ROOT}/destinations"
  SOVIEZ_BACKUP_SECRETS_DIR="${SOVIEZ_BACKUP_ROOT}/secrets"
  SOVIEZ_BACKUP_SCHEDULE_DIR="${SOVIEZ_BACKUP_ROOT}/schedules"
  SOVIEZ_BACKUP_DATA_DIR="${SOVIEZ_BACKUP_ROOT}/data"
  SOVIEZ_BACKUP_CANDIDATES_DIR="${SOVIEZ_BACKUP_ROOT}/candidates"
  SOVIEZ_BACKUP_STAGING_DIR="${SOVIEZ_BACKUP_ROOT}/staging"
  export SOVIEZ_BACKUP_ROOT SOVIEZ_BACKUP_INVENTORY_DIR SOVIEZ_BACKUP_OPS_DIR \
    SOVIEZ_BACKUP_DEST_DIR SOVIEZ_BACKUP_SECRETS_DIR SOVIEZ_BACKUP_SCHEDULE_DIR \
    SOVIEZ_BACKUP_DATA_DIR SOVIEZ_BACKUP_CANDIDATES_DIR SOVIEZ_BACKUP_STAGING_DIR
  mkdir -p "$SOVIEZ_BACKUP_ROOT" "$SOVIEZ_BACKUP_INVENTORY_DIR" "$SOVIEZ_BACKUP_OPS_DIR" \
    "$SOVIEZ_BACKUP_DEST_DIR" "$SOVIEZ_BACKUP_SECRETS_DIR" "$SOVIEZ_BACKUP_SCHEDULE_DIR" \
    "$SOVIEZ_BACKUP_DATA_DIR" "$SOVIEZ_BACKUP_CANDIDATES_DIR" "$SOVIEZ_BACKUP_STAGING_DIR"
  chmod 700 "$SOVIEZ_BACKUP_ROOT" "$SOVIEZ_BACKUP_SECRETS_DIR" "$SOVIEZ_BACKUP_OPS_DIR" \
    "$SOVIEZ_BACKUP_DATA_DIR" "$SOVIEZ_BACKUP_CANDIDATES_DIR" "$SOVIEZ_BACKUP_STAGING_DIR"
  chmod 755 "$SOVIEZ_BACKUP_INVENTORY_DIR" "$SOVIEZ_BACKUP_DEST_DIR" "$SOVIEZ_BACKUP_SCHEDULE_DIR"
}

soviez_backup_inventory_index() {
  printf '%s/index.json\n' "$SOVIEZ_BACKUP_INVENTORY_DIR"
}

soviez_backup_dir() {
  # Args: production_id backup_id
  printf '%s/%s/%s\n' "$SOVIEZ_BACKUP_DATA_DIR" "$1" "$2"
}

soviez_backup_object_file() {
  printf '%s/backup.json\n' "$(soviez_backup_dir "$1" "$2")"
}

soviez_backup_op_dir() {
  printf '%s/%s\n' "$SOVIEZ_BACKUP_OPS_DIR" "$1"
}

soviez_backup_op_state_file() {
  printf '%s/state.json\n' "$(soviez_backup_op_dir "$1")"
}

soviez_backup_staging_dir() {
  printf '%s/%s\n' "$SOVIEZ_BACKUP_STAGING_DIR" "$1"
}

soviez_backup_candidate_dir() {
  printf '%s/%s\n' "$SOVIEZ_BACKUP_CANDIDATES_DIR" "$1"
}

soviez_backup_dest_profile_file() {
  printf '%s/%s.json\n' "$SOVIEZ_BACKUP_DEST_DIR" "$1"
}

soviez_backup_dest_secret_file() {
  printf '%s/%s.secret\n' "$SOVIEZ_BACKUP_SECRETS_DIR" "$1"
}

soviez_backup_schedule_file() {
  printf '%s/%s.json\n' "$SOVIEZ_BACKUP_SCHEDULE_DIR" "$1"
}
