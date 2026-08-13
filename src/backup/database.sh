# shellcheck shell=bash

soviez_backup_pg_available() {
  [[ "${SOVIEZ_STAGE_USE_LIVE_PG:-0}" == "1" ]] && return 0
  [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && return 0
  [[ -n "${SOVIEZ_PG_HOST:-}" ]] && return 0
  if command -v pg_dump >/dev/null 2>&1 && [[ -n "${SOVIEZ_PG_PASSWORD:-}${PGPASSWORD:-}" ]]; then
    return 0
  fi
  return 1
}

soviez_backup_pg_dump_fc() {
  # Args: database_name output_file
  # Password via PGPASSWORD env only — never argv.
  local db="$1" out="$2"
  mkdir -p "$(dirname "$out")"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] && ! soviez_backup_pg_available; then
    # Minimal custom-format-like fixture (PGDUMP header magic "PGDMP")
    printf 'PGDMP\x01\x01\x00FIXTURE db=%s\n' "$db" > "$out"
    printf 'soviez_backup_fixture=1\n' >> "$out"
    return 0
  fi

  if declare -F soviez_stage_pg_dump_fc >/dev/null 2>&1 && soviez_backup_pg_available; then
    soviez_stage_pg_dump_fc "$db" "$out" || soviez_backup_die BACKUP_DATABASE_FAILED "pg_dump failed for $db"
    return 0
  fi

  export PGPASSWORD="${PGPASSWORD:-${SOVIEZ_PG_PASSWORD:-}}"
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -e PGPASSWORD="$PGPASSWORD" "$SOVIEZ_PG_CONTAINER" \
      pg_dump -Fc -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" > "$out" \
      || soviez_backup_die BACKUP_DATABASE_FAILED "Container pg_dump failed for $db"
  elif command -v pg_dump >/dev/null 2>&1; then
    pg_dump -Fc \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" \
      -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" \
      -d "$db" \
      -f "$out" \
      || soviez_backup_die BACKUP_DATABASE_FAILED "pg_dump failed for $db"
  else
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      printf 'PGDMP\x01\x01\x00FIXTURE db=%s\n' "$db" > "$out"
      return 0
    fi
    soviez_backup_die BACKUP_DATABASE_FAILED "pg_dump unavailable"
  fi
}

soviez_backup_pg_restore_fc() {
  # Args: database_name dump_file
  local db="$1" dump="$2"
  [[ -f "$dump" ]] || soviez_backup_die BACKUP_DATABASE_FAILED "Missing dump: $dump"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] && ! soviez_backup_pg_available; then
    local dest="${SOVIEZ_ROOT:-/tmp}/restore-dbs/$db"
    mkdir -p "$dest"
    cp -f "$dump" "$dest/db.dump"
    return 0
  fi

  if declare -F soviez_stage_pg_restore_fc >/dev/null 2>&1 && soviez_backup_pg_available; then
    if declare -F soviez_stage_pg_createdb >/dev/null 2>&1; then
      soviez_stage_pg_createdb "$db" 2>/dev/null || true
    fi
    soviez_stage_pg_restore_fc "$db" "$dump" || soviez_backup_die BACKUP_DATABASE_FAILED "pg_restore failed for $db"
    return 0
  fi

  export PGPASSWORD="${PGPASSWORD:-${SOVIEZ_PG_PASSWORD:-}}"
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -i -e PGPASSWORD="$PGPASSWORD" "$SOVIEZ_PG_CONTAINER" \
      pg_restore -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" --no-owner --exit-on-error < "$dump" \
      || soviez_backup_die BACKUP_DATABASE_FAILED "Container pg_restore failed"
  else
    pg_restore \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" \
      -d "$db" --no-owner --exit-on-error "$dump" \
      || soviez_backup_die BACKUP_DATABASE_FAILED "pg_restore failed"
  fi
}

soviez_backup_dump_production_db() {
  # Args: production_json output_file
  local prod_json="$1" out="$2"
  local db_name db_path
  db_name="$(soviez_json_get "$prod_json" database_name 2>/dev/null \
    || soviez_json_get "$prod_json" db_name 2>/dev/null || true)"
  db_path="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"

  if [[ -z "$db_name" || "$db_name" == "null" ]]; then
    db_name="$(soviez_json_get "$prod_json" tenant_id 2>/dev/null || echo production)"
  fi

  # Prefer live dump when PG is available (closes Stage live-DB debt path too)
  if soviez_backup_pg_available || [[ "${SOVIEZ_STAGE_USE_LIVE_PG:-0}" == "1" ]]; then
    soviez_backup_pg_dump_fc "$db_name" "$out"
    return 0
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    if [[ -n "$db_path" && -f "$db_path" ]]; then
      cp -a "$db_path" "$out"
    elif [[ -n "$db_path" && -d "$db_path" ]]; then
      tar -C "$db_path" -cf - . 2>/dev/null | { printf 'PGDMP\x01FIXTURE_DIR\n'; cat; } > "$out"
    else
      printf 'PGDMP\x01\x01\x00FIXTURE db=%s\n' "$db_name" > "$out"
    fi
    return 0
  fi

  soviez_backup_die BACKUP_DATABASE_FAILED "Live PostgreSQL not available for dump"
}
