# shellcheck shell=bash

soviez_backup_export() {
  # Args: backup_id output_path
  local backup_id="$1" out="${2:-}"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup_id required"
  [[ -n "$out" ]] || soviez_backup_die BACKUP_EXPORT_FAILED "output path required"
  local obj prod_id bdir
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  [[ -d "$bdir" ]] || soviez_backup_die BACKUP_NOT_FOUND "Backup directory missing"

  mkdir -p "$(dirname "$out")"
  # Package: tar of backup dir components (no secrets dir)
  tar -C "$bdir" -cf - . | {
    if command -v zstd >/dev/null 2>&1; then
      zstd -3 -q -o "$out"
    else
      gzip -c > "$out"
    fi
  } || soviez_backup_die BACKUP_EXPORT_FAILED "Export packaging failed"
  chmod 600 "$out"
  local sum
  sum="$(soviez_backup_sha256_file "$out")"
  printf '%s' "$sum" > "${out}.sha256"
  SOVIEZ_BID="$backup_id" SOVIEZ_OUT="$out" SOVIEZ_S="$sum" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "BACKUP_EXPORTED",
  "backup_id": os.environ["SOVIEZ_BID"],
  "output": os.environ["SOVIEZ_OUT"],
  "sha256": os.environ["SOVIEZ_S"],
}, separators=(",", ":")))
PY
}
