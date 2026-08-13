# shellcheck shell=bash

soviez_backup_filestore_compressor() {
  if command -v zstd >/dev/null 2>&1; then
    printf 'zstd\n'
  elif command -v gzip >/dev/null 2>&1; then
    printf 'gzip\n'
  else
    printf 'none\n'
  fi
}

soviez_backup_filestore_archive() {
  # Args: source_dir output_archive [compression_profile]
  local src="$1" out="$2" profile="${3:-balanced}"
  local comp level=3
  [[ -d "$src" ]] || soviez_backup_die BACKUP_FILESTORE_FAILED "Filestore path missing: $src"

  # Path safety: refuse if source is / or empty
  local abs
  abs="$(cd "$src" && pwd -P 2>/dev/null || pwd)"
  case "$abs" in
    /|/etc|/usr|/bin|/sbin|/var/lib/docker|/var/lib/containers)
      soviez_backup_die BACKUP_PATH_DENIED "Refusing unsafe filestore root: $abs"
      ;;
  esac

  mkdir -p "$(dirname "$out")"
  if declare -F soviez_backup_compression_level >/dev/null 2>&1; then
    level="$(soviez_backup_compression_level "$profile")"
  fi
  comp="$(soviez_backup_filestore_compressor)"

  # Stream tar; never follow symlink escapes outside tree (-h not used; store symlinks as links)
  case "$comp" in
    zstd)
      if tar -C "$abs" --exclude='./lost+found' -cf - . \
        | zstd -"$level" -q -o "$out" 2>/dev/null; then
        :
      elif tar -C "$abs" --exclude='./lost+found' -cf - . \
        | gzip -"$level" > "${out%.zst}.gz"; then
        mv "${out%.zst}.gz" "$out" 2>/dev/null || out="${out%.zst}.gz"
        comp="gzip"
      else
        soviez_backup_die BACKUP_FILESTORE_FAILED "filestore archive failed"
      fi
      ;;
    gzip)
      tar -C "$abs" --exclude='./lost+found' -cf - . \
        | gzip -"$level" > "$out" \
        || soviez_backup_die BACKUP_FILESTORE_FAILED "gzip filestore archive failed"
      ;;
    *)
      tar -C "$abs" --exclude='./lost+found' -cf "$out" . \
        || soviez_backup_die BACKUP_FILESTORE_FAILED "tar filestore archive failed"
      ;;
  esac
  printf '%s' "$comp"
}

soviez_backup_filestore_extract() {
  # Args: archive dest_dir
  local archive="$1" dest="$2"
  [[ -f "$archive" ]] || soviez_backup_die BACKUP_FILESTORE_FAILED "Missing filestore archive"
  mkdir -p "$dest"
  local dest_abs
  dest_abs="$(cd "$dest" && pwd -P 2>/dev/null || pwd)"
  case "$dest_abs" in
    /|/etc|/usr|/bin|/sbin)
      soviez_backup_die BACKUP_PATH_DENIED "Refusing extract to unsafe path: $dest_abs"
      ;;
  esac

  case "$archive" in
    *.zst|*.tar.zst)
      if command -v zstd >/dev/null 2>&1; then
        zstd -d -c "$archive" | tar -C "$dest_abs" -xf - \
          || soviez_backup_die BACKUP_FILESTORE_FAILED "zstd extract failed"
      else
        soviez_backup_die BACKUP_FILESTORE_FAILED "zstd required to extract archive"
      fi
      ;;
    *.gz|*.tgz|*.tar.gz)
      gzip -dc "$archive" | tar -C "$dest_abs" -xf - \
        || soviez_backup_die BACKUP_FILESTORE_FAILED "gzip extract failed"
      ;;
    *)
      tar -C "$dest_abs" -xf "$archive" \
        || soviez_backup_die BACKUP_FILESTORE_FAILED "tar extract failed"
      ;;
  esac
}
