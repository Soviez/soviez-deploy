# shellcheck shell=bash

soviez_migration_database_restore() {
  local pair_id="$1" op_id="$2" staging_id="$3"
  local dump staging_dir dest_db mode="fixture"
  local require_real=0
  dump="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc"
  [[ -f "$dump" ]] || dump="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc.verified"
  [[ -f "$dump" ]] || soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "Verified dump missing"
  staging_dir="$(soviez_migration_staging_dir "$staging_id")"
  mkdir -p "$staging_dir/database"
  dest_db="$staging_dir/database/restored.fc"
  cp -f "$dump" "$dest_db"

  if [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES:-0}" == "1" || "${SOVIEZ_MIG_REQUIRE_REAL_RESTORE:-0}" == "1" ]]; then
    require_real=1
  fi
  if [[ "$require_real" == "1" && -z "${SOVIEZ_MIG_PG_RESTORE_CID:-}" ]]; then
    soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "SOVIEZ_MIG_PG_RESTORE_CID required for real restore"
  fi

  if [[ -n "${SOVIEZ_MIG_PG_RESTORE_CID:-}" ]] && command -v docker >/dev/null 2>&1; then
    local raw_id="${staging_id//-/}"
    raw_id="${raw_id//_/}"
    local db_name="soviez_stg_${raw_id:0:12}"
    local pguser="${SOVIEZ_MIG_PG_USER:-}"
    if [[ -z "$pguser" ]]; then
      if docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
           psql -U postgres -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
        pguser=postgres
      else
        pguser=odoo
      fi
    fi
    docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
      psql -U "$pguser" -d postgres -c "DROP DATABASE IF EXISTS ${db_name};" >/dev/null 2>&1 || true
    docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
      psql -U "$pguser" -d postgres -c "CREATE DATABASE ${db_name};" >/dev/null || \
      soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "CREATE DATABASE failed"
    docker cp "$dest_db" "$SOVIEZ_MIG_PG_RESTORE_CID:/tmp/restore.fc" >/dev/null || \
      soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "docker cp dump failed"
    docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
      pg_restore -U "$pguser" -d "$db_name" --no-owner --no-acl /tmp/restore.fc >/dev/null 2>&1 || \
      soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "pg_restore failed"
    # Record count proof
    local rows
    rows="$(docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
      psql -U "$pguser" -d "$db_name" -Atc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null || echo 0)"
    printf '%s\n' "$db_name" > "$staging_dir/database/restored_db_name"
    printf '%s\n' "$rows" > "$staging_dir/database/table_count"
    mode="pg_restore_docker"
  elif [[ "$require_real" == "1" ]]; then
    soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "real pg_restore required"
  elif [[ "${SOVIEZ_MIG_FORCE_FIXTURE_DB:-0}" == "1" || "${SOVIEZ_MIG_TRANSFER_LOCAL:-0}" == "1" ]]; then
    mode="fixture"
  elif declare -F soviez_backup_pg_restore_fc >/dev/null 2>&1; then
    local db_name="soviez_staging_${staging_id}"
    soviez_backup_pg_restore_fc "$db_name" "$dest_db" || \
      soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "pg_restore failed"
    mode="pg_restore"
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mode="fixture"
  else
    soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "No restore backend available"
  fi
  if [[ "$require_real" == "1" && "$mode" == "fixture" ]]; then
    soviez_migration_die MIGRATION_DATABASE_RESTORE_FAILED "fixture restore forbidden in certification"
  fi
  printf '{"status":"restored","mode":"%s","path":"%s"}\n' "$mode" "$dest_db" > "$staging_dir/database/restore.json"
  cat "$staging_dir/database/restore.json"
}
