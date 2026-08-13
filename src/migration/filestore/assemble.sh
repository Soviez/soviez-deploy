# shellcheck shell=bash

soviez_migration_filestore_assemble() {
  local op_id="$1" staging_id="$2"
  local staging_fs
  staging_fs="$(soviez_migration_staging_dir "$staging_id")/filestore"
  mkdir -p "$staging_fs"
  # Copy assembled chunk objects marked filestore if present
  local chunks_dir
  chunks_dir="$(soviez_migration_transfer_chunks_dir "$op_id")/assembled"
  if [[ -d "$chunks_dir" ]]; then
    cp -f "$chunks_dir"/* "$staging_fs/" 2>/dev/null || true
  fi
  # Apply fixture filestore if provided
  if [[ -n "${SOVIEZ_MIG_FIXTURE_FILESTORE:-}" && -d "${SOVIEZ_MIG_FIXTURE_FILESTORE}" ]]; then
    cp -a "${SOVIEZ_MIG_FIXTURE_FILESTORE}/." "$staging_fs/" 2>/dev/null || true
  fi
  printf '{"status":"assembled","path":"%s"}\n' "$staging_fs"
}
