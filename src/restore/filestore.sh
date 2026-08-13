# shellcheck shell=bash

soviez_restore_filestore_into_candidate() {
  # Args: op_id backup_object_json
  local op_id="$1" backup="$2"
  local prod_id backup_id bdir cdir arch
  prod_id="$(soviez_json_get "$backup" production_id)"
  backup_id="$(soviez_json_get "$backup" backup_id)"
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  mkdir -p "$cdir/filestore"

  arch=""
  for cand in filestore.tar.zst filestore.tar.gz filestore.tar \
              filestore.tar.zst.enc filestore.tar.gz.enc; do
    [[ -f "$bdir/$cand" ]] && { arch="$bdir/$cand"; break; }
  done
  [[ -n "$arch" ]] || soviez_restore_die RESTORE_CANDIDATE_FAILED "Missing filestore archive"

  local src="$arch"
  if [[ "$arch" == *.enc ]]; then
    src="$cdir/filestore.archive"
    soviez_backup_decrypt_file "$arch" "$src" \
      || soviez_restore_die RESTORE_ENCRYPTION_KEY_INVALID "Failed to decrypt filestore"
  fi
  soviez_backup_filestore_extract "$src" "$cdir/filestore" \
    || soviez_restore_die RESTORE_CANDIDATE_FAILED "Filestore extract failed"
}
