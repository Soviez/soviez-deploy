# shellcheck shell=bash

soviez_restore_database_into_candidate() {
  # Args: op_id backup_object_json
  local op_id="$1" backup="$2"
  local prod_id backup_id bdir cdir dump
  prod_id="$(soviez_json_get "$backup" production_id)"
  backup_id="$(soviez_json_get "$backup" backup_id)"
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  mkdir -p "$cdir/db"

  dump="$bdir/db.dump"
  if [[ -f "$bdir/db.dump.enc" ]]; then
    if ! declare -F soviez_backup_decrypt_file >/dev/null 2>&1; then
      soviez_restore_die RESTORE_ENCRYPTION_KEY_REQUIRED "Decrypt helper missing"
    fi
    soviez_backup_decrypt_file "$bdir/db.dump.enc" "$cdir/db/db.dump" \
      || soviez_restore_die RESTORE_ENCRYPTION_KEY_INVALID "Failed to decrypt database dump"
    dump="$cdir/db/db.dump"
  elif [[ -f "$dump" ]]; then
    cp -a "$dump" "$cdir/db/db.dump"
    dump="$cdir/db/db.dump"
  else
    soviez_restore_die RESTORE_CANDIDATE_FAILED "Missing database dump"
  fi

  local testdb="rst_$(printf '%s' "$op_id" | tr -cd 'a-zA-Z0-9' | cut -c1-24)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'restored_db=%s\n' "$testdb" > "$cdir/db/restored.marker"
  else
    soviez_backup_pg_restore_fc "$testdb" "$dump" \
      || soviez_restore_die RESTORE_CANDIDATE_FAILED "pg_restore into candidate failed"
  fi
  printf '%s' "$testdb" > "$cdir/runtime/candidate_db_name.txt"
}
