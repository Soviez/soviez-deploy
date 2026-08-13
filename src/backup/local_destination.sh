# shellcheck shell=bash

soviez_backup_local_allowed_roots() {
  local roots="${SOVIEZ_BACKUP_ALLOWED_ROOTS:-}"
  if [[ -z "$roots" ]]; then
    soviez_backup_paths_init
    roots="$SOVIEZ_BACKUP_DATA_DIR"
  fi
  printf '%s\n' "$roots"
}

soviez_backup_local_path_allowed() {
  local path="$1"
  local abs root
  abs="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)/$(basename "$path")" 2>/dev/null || abs="$path"
  # Resolve existing path
  if [[ -e "$path" ]]; then
    abs="$(cd "$path" 2>/dev/null && pwd -P || readlink -f "$path" 2>/dev/null || echo "$path")"
  fi
  local IFS=':'
  local allowed=0
  for root in $(soviez_backup_local_allowed_roots); do
    [[ -n "$root" ]] || continue
    local root_abs
    root_abs="$(cd "$root" 2>/dev/null && pwd -P || echo "$root")"
    case "$abs" in
      "$root_abs"|"$root_abs"/*) allowed=1; break ;;
    esac
  done
  [[ "$allowed" == "1" ]]
}

soviez_backup_local_dest_validate() {
  local profile="$1"
  local path
  path="$(soviez_json_get "$profile" path)"
  [[ -n "$path" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "local path required"
  case "$path" in
    /*) ;;
    *) soviez_backup_die BACKUP_DESTINATION_INVALID "local path must be absolute" ;;
  esac
  mkdir -p "$path"
  chmod 700 "$path" 2>/dev/null || true
  local abs
  abs="$(cd "$path" && pwd -P)"
  soviez_backup_local_path_allowed "$abs" \
    || soviez_backup_die BACKUP_DESTINATION_DENIED "Path not under allowlisted roots: $abs"
  # Refuse obvious dangerous locations
  case "$abs" in
    */filestore|*/filestore/*|*/postgres/*|*/docker/overlay2*|*/candidates/*)
      soviez_backup_die BACKUP_DESTINATION_DENIED "Destination collides with runtime path"
      ;;
  esac
  [[ -w "$abs" ]] || soviez_backup_die BACKUP_DESTINATION_DENIED "Destination not writable: $abs"
  # Ownership marker
  printf 'soviez-backup-destination\n' > "$abs/.soviez-backup-destination"
  chmod 644 "$abs/.soviez-backup-destination"
  printf '%s' "$abs"
}

soviez_backup_local_dest_test() {
  local profile="$1"
  local abs
  abs="$(soviez_backup_local_dest_validate "$profile")"
  soviez_backup_ok BACKUP_DESTINATION_OK "Local destination reachable: $abs"
}

soviez_backup_local_dest_put() {
  # Args: profile_json source_dir backup_id production_id
  local profile="$1" src="$2" backup_id="$3" prod_id="$4"
  local abs dest
  abs="$(soviez_backup_local_dest_validate "$profile")"
  dest="$abs/$prod_id/$backup_id"
  mkdir -p "$dest"
  chmod 700 "$dest"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    cp -a "$src"/. "$dest/" || soviez_backup_die BACKUP_TRANSFER_FAILED "local copy failed"
  else
    cp -a "$src"/. "$dest/" || soviez_backup_die BACKUP_TRANSFER_FAILED "local copy failed"
  fi
  printf '%s' "$dest"
}
