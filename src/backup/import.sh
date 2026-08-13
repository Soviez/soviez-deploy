# shellcheck shell=bash

soviez_backup_import() {
  # Args: package_path [confirm]
  local pkg="$1" confirm="${2:-0}"
  [[ -f "$pkg" ]] || soviez_backup_die BACKUP_IMPORT_INVALID "Package not found"
  if [[ "$confirm" != "1" && "${SOVIEZ_BACKUP_ASSUME_YES:-0}" != "1" && ! -t 0 ]]; then
    soviez_backup_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Import requires --confirm"
  fi

  soviez_backup_paths_init
  local qdir
  qdir="$(soviez_backup_staging_dir "import-$$")"
  rm -rf "$qdir"
  mkdir -p "$qdir/extract"
  chmod 700 "$qdir"

  # Quarantine copy
  cp -a "$pkg" "$qdir/package.bin"
  if [[ -f "${pkg}.sha256" ]]; then
    local expected actual
    expected="$(tr -d '[:space:]' < "${pkg}.sha256" | awk '{print $1}')"
    actual="$(soviez_backup_sha256_file "$qdir/package.bin")"
    [[ "$expected" == "$actual" ]] || soviez_backup_die BACKUP_IMPORT_INVALID "Package checksum mismatch"
  fi

  case "$pkg" in
    *.zst|*.tar.zst)
      zstd -d -c "$qdir/package.bin" | tar -C "$qdir/extract" -xf - \
        || soviez_backup_die BACKUP_IMPORT_INVALID "Failed to extract package"
      ;;
    *.gz|*.tgz)
      gzip -dc "$qdir/package.bin" | tar -C "$qdir/extract" -xf - \
        || soviez_backup_die BACKUP_IMPORT_INVALID "Failed to extract package"
      ;;
    *)
      tar -C "$qdir/extract" -xf "$qdir/package.bin" \
        || soviez_backup_die BACKUP_IMPORT_INVALID "Failed to extract package"
      ;;
  esac

  local man obj backup_id prod_id
  man="$qdir/extract/manifest.json"
  [[ -f "$man" ]] || soviez_backup_die BACKUP_IMPORT_INVALID "Missing manifest in package"
  soviez_backup_manifest_verify "$man"

  if [[ -f "$qdir/extract/backup.json" ]]; then
    obj="$(cat "$qdir/extract/backup.json")"
  else
    obj="$(cat "$man")"
  fi
  backup_id="$(soviez_json_get "$obj" backup_id)"
  prod_id="$(soviez_json_get "$obj" production_id)"
  [[ -n "$backup_id" && -n "$prod_id" ]] || soviez_backup_die BACKUP_IMPORT_INVALID "Package missing ids"

  local dest
  dest="$(soviez_backup_dir "$prod_id" "$backup_id")"
  mkdir -p "$dest"
  cp -a "$qdir/extract"/. "$dest/"
  chmod 700 "$dest"
  soviez_backup_write_object "$prod_id" "$backup_id" "$obj" >/dev/null
  soviez_backup_inventory_upsert "$obj"
  # Level-1 verify after import
  soviez_backup_verify_level1 "$backup_id" >/dev/null || true
  rm -rf "$qdir"

  SOVIEZ_BID="$backup_id" SOVIEZ_P="$prod_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "BACKUP_IMPORTED",
  "backup_id": os.environ["SOVIEZ_BID"],
  "production_id": os.environ["SOVIEZ_P"],
}, separators=(",", ":")))
PY
}
