# shellcheck shell=bash
# Consistent Production snapshot via pg_dump (custom format) + filestore copy.
# Never mutates Production DB/filestore. Never copies live PG data directory.

soviez_stage_measure_path_bytes() {
  local path="$1"
  if [[ -d "$path" || -f "$path" ]]; then
    du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
  else
    echo 0
  fi
}

soviez_stage_snapshot_db() {
  # Args: op_id source_db_name [pg_container|host]
  local op_id="$1"
  local source_db="$2"
  local snap_dir dump_file
  snap_dir="$(soviez_stage_snapshot_dir "$op_id")"
  mkdir -p "$snap_dir"
  chmod 700 "$snap_dir"
  dump_file="$snap_dir/db.dump"

  if soviez_stage_use_live_pg 2>/dev/null; then
    # Real disposable/live path: custom-format pg_dump — never copy live PG data dir.
    local t0 t1
    t0="$(date +%s)"
    soviez_stage_pg_dump_fc "$source_db" "$dump_file" \
      || soviez_stage_die SNAPSHOT_FAILED "pg_dump -Fc failed"
    t1="$(date +%s)"
    printf '%s' "$((t1 - t0))" > "$snap_dir/db.dump.duration_sec"
    # Validate custom-format header (PGDMP)
    local magic
    magic="$(dd if="$dump_file" bs=5 count=1 2>/dev/null | tr -d '\0' || true)"
    [[ "$magic" == "PGDMP" ]] || soviez_stage_die SNAPSHOT_FAILED "Dump is not PostgreSQL custom format"
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Isolated fixture: write a deterministic "dump" from source fixture SQL or marker.
    local src_fixture="${SOVIEZ_STAGE_FIXTURE_DB_DUMP:-}"
    if [[ -n "$src_fixture" && -f "$src_fixture" ]]; then
      cp -f "$src_fixture" "$dump_file"
    else
      printf 'SOVIEZ_STAGE_PGDUMP_FIXTURE source_db=%s op=%s\n' "$source_db" "$op_id" > "$dump_file"
      # Embed a simple checksummable payload representing business rows.
      printf 'row:partner:Acme\nrow:invoice:100\n' >> "$dump_file"
    fi
  else
    # Prefer docker exec into managed postgres if named; else local pg_dump.
    local pg="${SOVIEZ_PG_CONTAINER:-soviez-db}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$pg"; then
      docker exec "$pg" pg_dump -Fc -d "$source_db" > "$dump_file" \
        || soviez_stage_die SNAPSHOT_FAILED "pg_dump via docker failed"
    else
      pg_dump -Fc -d "$source_db" -f "$dump_file" \
        || soviez_stage_die SNAPSHOT_FAILED "pg_dump failed"
    fi
    local magic
    magic="$(dd if="$dump_file" bs=5 count=1 2>/dev/null | tr -d '\0' || true)"
    [[ "$magic" == "PGDMP" ]] || soviez_stage_die SNAPSHOT_FAILED "Dump is not PostgreSQL custom format"
  fi

  local sum
  sum="$(soviez_sha256_file "$dump_file")"
  printf '%s' "$sum" > "$snap_dir/db.dump.sha256"
  printf '%s' "$dump_file"
}

soviez_stage_snapshot_filestore() {
  local op_id="$1"
  local source_fs="$2"
  local snap_dir dest
  snap_dir="$(soviez_stage_snapshot_dir "$op_id")"
  mkdir -p "$snap_dir"
  dest="$snap_dir/filestore"
  mkdir -p "$dest"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] && ! soviez_stage_use_live_pg; then
    local src_fixture="${SOVIEZ_STAGE_FIXTURE_FILESTORE:-$source_fs}"
    mkdir -p "$src_fixture"
    if [[ ! -f "$src_fixture/.soviez_fs_marker" ]]; then
      printf 'prod-filestore-marker\n' > "$src_fixture/.soviez_fs_marker"
      printf 'blob-a\n' > "$src_fixture/attachment-a.bin"
    fi
    # Copy — never symlink to Production.
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src_fixture/." "$dest/"
  else
    [[ -d "$source_fs" ]] || soviez_stage_die SNAPSHOT_FAILED "Source filestore missing: $source_fs"
    rm -rf "$dest"
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$source_fs"/ "$dest"/ \
        || soviez_stage_die SNAPSHOT_FAILED "filestore rsync failed"
    else
      cp -a "$source_fs"/. "$dest"/ \
        || soviez_stage_die SNAPSHOT_FAILED "filestore copy failed"
    fi
  fi

  # Reject if destination somehow became a symlink to source.
  if [[ -L "$dest" ]]; then
    soviez_stage_die FILESTORE_CLONE_FAILED "Filestore snapshot must not be a symlink"
  fi

  local sum
  sum="$( (cd "$dest" && find . -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}') )"
  printf '%s' "$sum" > "$snap_dir/filestore.sha256"
  # Record source checksum for Production-unchanged proofs in tests.
  if [[ -d "$source_fs" ]]; then
    local src_sum
    src_sum="$( (cd "$source_fs" && find . -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}') )"
    printf '%s' "$src_sum" > "$snap_dir/filestore.source.sha256"
  fi
  printf '%s' "$dest"
}

soviez_sha256_file() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    sha256sum "$f" | awk '{print $1}'
  fi
}

soviez_sha256_hex() {
  printf '%s' "$1" | openssl dgst -sha256 | awk '{print $NF}'
}
