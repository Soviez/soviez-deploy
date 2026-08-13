# shellcheck shell=bash
# Restore snapshot into Stage-owned DB and filestore (no Production mutation).

soviez_stage_restore_database() {
  local op_id="$1"
  local stage_db="$2"
  local dump_file="$3"
  [[ -f "$dump_file" ]] || soviez_stage_die DATABASE_RESTORE_FAILED "Missing dump: $dump_file"

  local stage_uuid
  stage_uuid="$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || openssl rand -hex 16)"

  if soviez_stage_use_live_pg 2>/dev/null; then
    if ! soviez_stage_pg_createdb "$stage_db"; then
      soviez_stage_die STAGE_DB_CONFLICT "Stage database already exists: $stage_db"
    fi
    local t0 t1
    t0="$(date +%s)"
    soviez_stage_pg_restore_fc "$stage_db" "$dump_file" \
      || soviez_stage_die DATABASE_RESTORE_FAILED "pg_restore failed"
    t1="$(date +%s)"
    printf '%s' "$((t1 - t0))" > "$(soviez_stage_snapshot_dir "$op_id")/db.restore.duration_sec"
    # Never alter Production UUID — rotate only Stage DB parameter.
    soviez_stage_pg_rotate_uuid "$stage_db" "$stage_uuid"
    printf '%s' "$stage_uuid"
    return 0
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local db_dir="$SOVIEZ_ROOT/stage-dbs/$stage_db"
    if [[ -d "$db_dir" && -n "$(ls -A "$db_dir" 2>/dev/null || true)" ]]; then
      soviez_stage_die STAGE_DB_CONFLICT "Non-empty Stage DB fixture exists: $stage_db"
    fi
    mkdir -p "$db_dir"
    cp -f "$dump_file" "$db_dir/restored.dump"
    printf '%s' "$stage_uuid" > "$db_dir/database.uuid"
    printf 'database.is_neutralized=false\n' > "$db_dir/ir_config_parameter.env"
    printf '%s' "$stage_uuid"
    return 0
  fi

  local pg="${SOVIEZ_PG_CONTAINER:-soviez-db}"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$pg"; then
    if docker exec "$pg" psql -Atc "SELECT 1 FROM pg_database WHERE datname='${stage_db}'" | grep -q 1; then
      soviez_stage_die STAGE_DB_CONFLICT "Stage database already exists: $stage_db"
    fi
    docker exec "$pg" createdb "$stage_db" \
      || soviez_stage_die DATABASE_RESTORE_FAILED "createdb failed"
    docker exec -i "$pg" pg_restore -d "$stage_db" --no-owner --role=odoo < "$dump_file" \
      || soviez_stage_die DATABASE_RESTORE_FAILED "pg_restore failed"
  else
    createdb "$stage_db" || soviez_stage_die DATABASE_RESTORE_FAILED "createdb failed"
    pg_restore -d "$stage_db" --no-owner "$dump_file" \
      || soviez_stage_die DATABASE_RESTORE_FAILED "pg_restore failed"
  fi
  printf '%s' "$stage_uuid"
}

soviez_stage_restore_filestore() {
  local stage_id="$1"
  local snap_fs="$2"
  local dest
  dest="$(soviez_stage_filestore_path "$stage_id")"
  [[ -d "$snap_fs" ]] || soviez_stage_die FILESTORE_CLONE_FAILED "Missing filestore snapshot"
  # Stage root parent
  mkdir -p "$(dirname "$dest")"
  # Ensure no shared writable link to Production.
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
  fi
  local tmp="${dest}.promoting"
  rm -rf "$tmp" "${dest}.bak"
  mkdir -p "$tmp"
  cp -a "$snap_fs"/. "$tmp"/
  # Atomic-ish promotion: replace dest entirely (never mv into existing dest dir).
  if [[ -e "$dest" ]]; then
    mv "$dest" "${dest}.bak"
  fi
  mv "$tmp" "$dest"
  rm -rf "${dest}.bak" 2>/dev/null || true
  chmod -R u+rwX,g+rX,o-rwx "$dest" 2>/dev/null || true

  if find "$dest" -type l | grep -q .; then
    # Symlinks inside filestore pointing outside stage dir are suspicious.
    while IFS= read -r link; do
      local target
      target="$(readlink "$link")"
      case "$target" in
        /*)
          case "$target" in
            "$dest"/*) ;;
            *) soviez_stage_die FILESTORE_CLONE_FAILED "External symlink in Stage filestore: $link -> $target" ;;
          esac
          ;;
      esac
    done < <(find "$dest" -type l)
  fi
}
