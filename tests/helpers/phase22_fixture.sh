#!/usr/bin/env bash
# Phase 22 disposable fixtures — builds on Phase 21 cutover.
# shellcheck shell=bash

SOVIEZ_P22_FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/phase21_fixture.sh
source "$SOVIEZ_P22_FIXTURE_DIR/phase21_fixture.sh"

# Start disposable Postgres for real pg_dump/pg_restore certification.
# Prefers docker (Colima DOCKER_HOST), else local psql/createdb/pg_dump/pg_restore.
soviez_phase22_fixture_start_postgres() {
  # Idempotent: already have a live docker dump target.
  if [[ -n "${SOVIEZ_MIG_PG_DUMP_CID:-}" ]] && command -v docker >/dev/null 2>&1; then
    if docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "${SOVIEZ_MIG_PG_DUMP_CID}" \
         pg_isready -U "${SOVIEZ_MIG_PG_USER:-postgres}" >/dev/null 2>&1; then
      return 0
    fi
  fi

  export SOVIEZ_MIG_P22_SOURCE_DB_NAME="${SOVIEZ_MIG_P22_SOURCE_DB_NAME:-soviez_p22_src}"
  export SOVIEZ_MIG_SOURCE_DB_NAME="$SOVIEZ_MIG_P22_SOURCE_DB_NAME"
  # Do NOT copy synthetic pinned dump as the source archive input.
  unset SOVIEZ_MIG_FIXTURE_DB_DUMP 2>/dev/null || true

  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

  local db_name="$SOVIEZ_MIG_P22_SOURCE_DB_NAME"
  local started=0

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 \
     && [[ "${SOVIEZ_MIG_P22_SKIP_DOCKER_PG:-0}" != "1" ]]; then
    local name="soviez-p22-pg-$$"
    docker rm -f "$name" >/dev/null 2>&1 || true
    if docker run -d --name "$name" \
         -e POSTGRES_PASSWORD=soviez -e POSTGRES_USER=postgres -e POSTGRES_DB=postgres \
         postgres:16-alpine >/tmp/soviez-p22-pg-run.out 2>&1; then
      local i
      for i in $(seq 1 60); do
        docker exec -e PGPASSWORD=soviez "$name" pg_isready -U postgres >/dev/null 2>&1 && break
        sleep 1
      done
      if docker exec -e PGPASSWORD=soviez "$name" pg_isready -U postgres >/dev/null 2>&1; then
        docker exec -e PGPASSWORD=soviez "$name" \
          psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${db_name};" >/dev/null
        docker exec -e PGPASSWORD=soviez "$name" \
          psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${db_name};" >/dev/null
        docker exec -e PGPASSWORD=soviez "$name" \
          psql -U postgres -d "$db_name" -v ON_ERROR_STOP=1 -c \
          "CREATE TABLE p22_archive_probe(id int primary key, v text); INSERT INTO p22_archive_probe VALUES (1, 'ok');" >/dev/null
        export SOVIEZ_MIG_PG_DUMP_CID="$name"
        export SOVIEZ_MIG_PG_PASSWORD=soviez
        export SOVIEZ_MIG_PG_USER=postgres
        export SOVIEZ_MIG_P22_PG_MODE=docker
        started=1
      else
        docker rm -f "$name" >/dev/null 2>&1 || true
      fi
    fi
  fi

  if [[ "$started" -ne 1 ]]; then
    # Local postgres fallback (user postgres or current user).
    local pg_user="${SOVIEZ_MIG_PG_USER:-}"
    if [[ -z "$pg_user" ]]; then
      if command -v psql >/dev/null 2>&1 && psql -U postgres -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
        pg_user=postgres
      elif command -v psql >/dev/null 2>&1 && psql -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
        pg_user="$(whoami)"
      else
        echo "soviez_phase22_fixture_start_postgres: no docker or local postgres" >&2
        return 1
      fi
    fi
    export SOVIEZ_MIG_PG_USER="$pg_user"
    unset SOVIEZ_MIG_PG_DUMP_CID 2>/dev/null || true
    dropdb -U "$pg_user" --if-exists "$db_name" 2>/dev/null || true
    createdb -U "$pg_user" "$db_name" || return 1
    psql -U "$pg_user" -d "$db_name" -v ON_ERROR_STOP=1 -c \
      "CREATE TABLE p22_archive_probe(id int primary key, v text); INSERT INTO p22_archive_probe VALUES (1, 'ok');" >/dev/null || return 1
    export SOVIEZ_MIG_P22_PG_MODE=local
    export SOVIEZ_MIG_P22_LOCAL_SRC_DB="$db_name"
    started=1
  fi

  [[ "$started" -eq 1 ]]
}

soviez_phase22_fixture_cleanup_postgres() {
  # Stop disposable container; do not delete on-disk source filestore/config.
  if [[ -n "${SOVIEZ_MIG_PG_DUMP_CID:-}" ]] && command -v docker >/dev/null 2>&1; then
    docker rm -f "${SOVIEZ_MIG_PG_DUMP_CID}" >/dev/null 2>&1 || true
    unset SOVIEZ_MIG_PG_DUMP_CID 2>/dev/null || true
  fi
  # Drop only local fixture source DB (restore targets already destroyed by restore_test).
  if [[ "${SOVIEZ_MIG_P22_PG_MODE:-}" == "local" && -n "${SOVIEZ_MIG_P22_LOCAL_SRC_DB:-}" ]]; then
    dropdb -U "${SOVIEZ_MIG_PG_USER:-postgres}" --if-exists "${SOVIEZ_MIG_P22_LOCAL_SRC_DB}" 2>/dev/null || true
  fi
  unset SOVIEZ_MIG_P22_PG_MODE SOVIEZ_MIG_P22_LOCAL_SRC_DB 2>/dev/null || true
}

soviez_phase22_fixture_init() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi

  soviez_phase21_fixture_init "$repo_root"

  export SOVIEZ_MIG_P22_FIXTURE=1
  export SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK=1
  export SOVIEZ_MIG_P22_CANONICAL=1
  # E2E/default: require real pg_dump/pg_restore. Unit paths may set this to 0.
  export SOVIEZ_MIG_P22_REQUIRE_REAL_PG="${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-1}"
  export SOVIEZ_MIG_P22_STABILIZATION_SECONDS=10
  export SOVIEZ_MIG_P22_OBSERVE_TICK_SECONDS=1
  # Allow override from caller env if already set to a short cert value.
  if [[ -n "${SOVIEZ_MIG_P22_STABILIZATION_SECONDS_OVERRIDE:-}" ]]; then
    export SOVIEZ_MIG_P22_STABILIZATION_SECONDS="$SOVIEZ_MIG_P22_STABILIZATION_SECONDS_OVERRIDE"
  fi
  export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
  export SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE=1
  export SOVIEZ_BACKUP_PASSPHRASE="${SOVIEZ_BACKUP_PASSPHRASE:-p22-fixture-passphrase}"
  export SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH
  SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH="$(date -u +%s)"

  # Seed source root + filestore
  local src_root
  src_root="$SOVIEZ_ROOT/p22_source"
  mkdir -p "$src_root/filestore/docs" "$src_root/config"
  printf 'hello-p22\n' > "$src_root/filestore/docs/readme.txt"
  printf 'cfg=1\n' > "$src_root/config/odoo.conf"
  mkdir -p "$src_root/erp_runtime"
  printf 'RUNNING\n' > "$src_root/erp_runtime/status"
  export SOVIEZ_MIG_P22_SOURCE_ROOT="$src_root"
  export SOVIEZ_MIG_P22_SOURCE_FILESTORE="$src_root/filestore"
  export SOVIEZ_MIG_P22_SOURCE_CONFIG="$src_root/config"
  export SOVIEZ_MIG_P22_ERP_RUNTIME_MARKER="$src_root/erp_runtime/status"

  # Pinned independent recovery copy (SEPARATE from source archive dump input).
  local pinned
  pinned="$SOVIEZ_ROOT/p22_pinned_backup"
  mkdir -p "$pinned"
  printf 'PINNED_ROLLBACK_BACKUP\n' > "$pinned/backup.marker"
  printf 'PGDMP\x01pinned\n' > "$pinned/dump.fc"
  export SOVIEZ_MIG_P22_PINNED_BACKUP="$pinned/dump.fc"
  # Never use pinned synthetic dump as SOVIEZ_MIG_FIXTURE_DB_DUMP under REQUIRE_REAL_PG.
  unset SOVIEZ_MIG_FIXTURE_DB_DUMP 2>/dev/null || true

  unset SOVIEZ_MIG_P22_INJECT_HTTP_FAIL SOVIEZ_MIG_P22_INJECT_INCIDENT \
    SOVIEZ_MIG_P22_INJECT_BACKUPS_FAIL SOVIEZ_MIG_P22_ACTIVE_ROLLBACK \
    SOVIEZ_MIG_P22_UNKNOWN_RESOURCES SOVIEZ_MIG_SOURCE_PURGE \
    SOVIEZ_MIG_P22_LEGAL_HOLD SOVIEZ_MIG_P22_RETENTION_HOLD \
    SOVIEZ_MIG_P22_INJECT_PUBLIC_ROUTE SOVIEZ_MIG_P22_INJECT_INTEGRATIONS_ACTIVE \
    SOVIEZ_MIG_P22_CREDENTIALS_INCOMPLETE SOVIEZ_MIG_P22_STAGE_MANDATORY_FAIL 2>/dev/null || true

  # Start real postgres when required (e2e default).
  if [[ "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" == "1" ]]; then
    soviez_phase22_fixture_start_postgres || \
      echo "WARN: start_postgres failed (REQUIRE_REAL_PG=1); archive steps will fail without PG" >&2
  fi
}

# Run cutover if needed and export CUTOVER_OP_ID / AUTH_ID / SOURCE_ID.
soviez_phase22_fixture_cutover() {
  # Ensure postgres is up for archive-capable cutover fixtures.
  if [[ "${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}" == "1" ]]; then
    soviez_phase22_fixture_start_postgres || \
      { echo "FAIL: REQUIRE_REAL_PG=1 but postgres unavailable" >&2; return 1; }
  fi
  export SOVIEZ_CLI_YES=1
  local result
  result="$(soviez_migration_cutover_start "$PAIR_ID" 1)"
  export CUTOVER_OP_ID
  CUTOVER_OP_ID="$(soviez_json_get "$result" operation_id)"
  export SOVIEZ_MIG_P22_CUTOVER_ID="$CUTOVER_OP_ID"
  export AUTH_ID
  AUTH_ID="$(soviez_json_get "$result" authorization_id)"
  export SOURCE_ID="$CUTOVER_OP_ID"
  printf '%s\n' "$result"
}
