# shellcheck shell=bash
# Live PostgreSQL helpers for Stage snapshot/restore (no live PG data-dir copy).

soviez_stage_use_live_pg() {
  [[ "${SOVIEZ_STAGE_USE_LIVE_PG:-0}" == "1" ]] && return 0
  [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && return 0
  [[ -n "${SOVIEZ_PG_HOST:-}" ]] && return 0
  return 1
}

soviez_stage_pg_psql() {
  # Args forwarded to psql. Uses container or host connection.
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -i -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      psql -v ON_ERROR_STOP=1 -U "${SOVIEZ_PG_USER:-postgres}" "$@"
  else
    PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" psql -v ON_ERROR_STOP=1 \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" \
      -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" \
      "$@"
  fi
}

soviez_stage_pg_dump_fc() {
  # Args: database_name output_file
  local db="$1"
  local out="$2"
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      pg_dump -Fc -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" > "$out"
  else
    PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" pg_dump -Fc \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" \
      -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" \
      -d "$db" \
      -f "$out"
  fi
}

soviez_stage_pg_createdb() {
  local db="$1"
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    if docker exec -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      psql -At -U "${SOVIEZ_PG_USER:-postgres}" -d postgres -c "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
      return 1
    fi
    docker exec -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      createdb -U "${SOVIEZ_PG_USER:-postgres}" "$db"
  else
    if PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" psql -At \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" -d postgres \
      -c "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
      return 1
    fi
    PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" createdb \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" "$db"
  fi
}

soviez_stage_pg_restore_fc() {
  local db="$1"
  local dump="$2"
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -i -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      pg_restore -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" --no-owner --exit-on-error < "$dump"
  else
    PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" pg_restore \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" \
      -d "$db" --no-owner --exit-on-error "$dump"
  fi
}

soviez_stage_pg_query_at() {
  local db="$1"
  shift
  if [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$SOVIEZ_PG_CONTAINER"; then
    docker exec -e PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" "$SOVIEZ_PG_CONTAINER" \
      psql -At -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" -c "$*"
  else
    PGPASSWORD="${SOVIEZ_PG_PASSWORD:-}" psql -At \
      -h "${SOVIEZ_PG_HOST:-127.0.0.1}" -p "${SOVIEZ_PG_PORT:-5432}" \
      -U "${SOVIEZ_PG_USER:-postgres}" -d "$db" -c "$*"
  fi
}

soviez_stage_pg_rotate_uuid() {
  # Args: stage_db new_uuid — updates ir_config_parameter-style table when present.
  local db="$1"
  local new_uuid="$2"
  soviez_stage_pg_query_at "$db" \
    "CREATE TABLE IF NOT EXISTS ir_config_parameter (key text PRIMARY KEY, value text);" >/dev/null || true
  soviez_stage_pg_query_at "$db" \
    "INSERT INTO ir_config_parameter(key,value) VALUES ('database.uuid','${new_uuid}')
     ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value;" >/dev/null || true
  soviez_stage_pg_query_at "$db" \
    "INSERT INTO ir_config_parameter(key,value) VALUES ('database.is_stage','true')
     ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value;" >/dev/null || true
}
