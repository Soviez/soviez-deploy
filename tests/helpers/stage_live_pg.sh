#!/usr/bin/env bash
# Helpers for disposable PostgreSQL containers (already-present postgres:16 image).
# shellcheck shell=bash

soviez_test_alloc_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

soviez_test_pg_stop() {
  # Prefer explicit name; never expand unset SOVIEZ_TEST_PG_CONTAINER under set -u.
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    name="${SOVIEZ_TEST_PG_CONTAINER:-}"
  fi
  [[ -n "$name" ]] || return 0
  docker rm -f "$name" >/dev/null 2>&1 || true
}

soviez_test_pg_start() {
  # Args: name_suffix → sets SOVIEZ_TEST_PG_* env
  local suffix="${1:-live}"
  local name="soviez-stage-pg-${suffix}-$$"
  local port pass attempt
  # Preflight: refuse start when Docker root filesystem is critically full.
  if declare -F soviez_phase23_docker_disk_ok >/dev/null 2>&1; then
    soviez_phase23_docker_disk_ok || return 1
  fi
  port="$(soviez_test_alloc_port)"
  pass="$(openssl rand -hex 12)"
  docker rm -f "$name" >/dev/null 2>&1 || true
  for attempt in 1 2 3; do
    if docker run -d --name "$name" \
      --label "soviez.phase23.disposable=1" \
      --label "soviez.fixture=stage-pg" \
      -e POSTGRES_PASSWORD="$pass" \
      -e POSTGRES_USER=soviez \
      -e POSTGRES_DB=postgres \
      -p "127.0.0.1:${port}:5432" \
      postgres:16 >/dev/null; then
      break
    fi
    docker rm -f "$name" >/dev/null 2>&1 || true
    port="$(soviez_test_alloc_port)"
    sleep 1
  done
  # Confirm container is running before readiness loop
  if ! docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true; then
    echo "[stage_live_pg] container failed to start: $name" >&2
    docker logs "$name" 2>&1 | tail -30 >&2 || true
    docker rm -f "$name" >/dev/null 2>&1 || true
    return 1
  fi
  local i=0
  while ! docker exec "$name" pg_isready -U soviez >/dev/null 2>&1; do
    i=$((i + 1))
    if [[ $i -ge 60 ]]; then
      echo "[stage_live_pg] pg_isready timeout: $name" >&2
      docker logs "$name" 2>&1 | tail -30 >&2 || true
      docker rm -f "$name" >/dev/null 2>&1 || true
      return 1
    fi
    # Detect death mid-wait (disk full, OOM, etc.)
    if ! docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true; then
      echo "[stage_live_pg] container died during readiness: $name" >&2
      docker logs "$name" 2>&1 | tail -40 >&2 || true
      docker rm -f "$name" >/dev/null 2>&1 || true
      return 1
    fi
    sleep 0.5
  done
  # Extra settle — avoid race with concurrent docker admin commands.
  sleep 1
  docker exec "$name" pg_isready -U soviez >/dev/null
  export SOVIEZ_TEST_PG_CONTAINER="$name"
  export SOVIEZ_TEST_PG_PORT="$port"
  export SOVIEZ_TEST_PG_USER=soviez
  export SOVIEZ_TEST_PG_PASSWORD="$pass"
  export SOVIEZ_TEST_PG_HOST=127.0.0.1
}

soviez_test_pg_seed_source() {
  # Creates deterministic source DB with schema, rows, uuid, attachment refs.
  local db="${1:-soviez_prod_source}"
  local fs="${2:?filestore path required}"
  mkdir -p "$fs/attachments"
  printf 'binary-attachment-payload-v1\n' > "$fs/attachments/doc1.bin"
  local fs_sum
  fs_sum="$(openssl dgst -sha256 "$fs/attachments/doc1.bin" | awk '{print $NF}')"

  if [[ -n "${SOVIEZ_TEST_PG_CONTAINER:-}" ]]; then
    docker exec -e PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD" "$SOVIEZ_TEST_PG_CONTAINER" \
      createdb -U "$SOVIEZ_TEST_PG_USER" "$db"
    docker exec -i -e PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD" "$SOVIEZ_TEST_PG_CONTAINER" \
      psql -v ON_ERROR_STOP=1 -U "$SOVIEZ_TEST_PG_USER" -d "$db" <<SQL
CREATE TABLE ir_config_parameter (
  key text PRIMARY KEY,
  value text NOT NULL
);
INSERT INTO ir_config_parameter(key,value) VALUES
  ('database.uuid', 'db-uuid-prod-live-1'),
  ('web.base.url', 'https://prod.example.com');

CREATE TABLE res_partner (
  id serial PRIMARY KEY,
  name text NOT NULL,
  email text
);
INSERT INTO res_partner(name, email) VALUES
  ('Acme Corp', 'acme@example.com'),
  ('Beta LLC', 'beta@example.com');

CREATE TABLE account_move (
  id serial PRIMARY KEY,
  partner_id int REFERENCES res_partner(id),
  amount numeric(12,2) NOT NULL,
  name text NOT NULL
);
INSERT INTO account_move(partner_id, amount, name) VALUES
  (1, 100.00, 'INV/001'),
  (1, 250.50, 'INV/002'),
  (2, 40.00, 'INV/003');

CREATE TABLE ir_attachment (
  id serial PRIMARY KEY,
  name text NOT NULL,
  store_fname text NOT NULL,
  checksum text NOT NULL,
  res_model text,
  res_id int
);
INSERT INTO ir_attachment(name, store_fname, checksum, res_model, res_id) VALUES
  ('doc1.bin', 'attachments/doc1.bin', '${fs_sum}', 'account.move', 1);
SQL
  else
    export PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD"
    createdb -h "$SOVIEZ_TEST_PG_HOST" -p "$SOVIEZ_TEST_PG_PORT" -U "$SOVIEZ_TEST_PG_USER" "$db"
    psql -h "$SOVIEZ_TEST_PG_HOST" -p "$SOVIEZ_TEST_PG_PORT" -U "$SOVIEZ_TEST_PG_USER" -d "$db" -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE ir_config_parameter (
  key text PRIMARY KEY,
  value text NOT NULL
);
INSERT INTO ir_config_parameter(key,value) VALUES
  ('database.uuid', 'db-uuid-prod-live-1'),
  ('web.base.url', 'https://prod.example.com');

CREATE TABLE res_partner (
  id serial PRIMARY KEY,
  name text NOT NULL,
  email text
);
INSERT INTO res_partner(name, email) VALUES
  ('Acme Corp', 'acme@example.com'),
  ('Beta LLC', 'beta@example.com');

CREATE TABLE account_move (
  id serial PRIMARY KEY,
  partner_id int REFERENCES res_partner(id),
  amount numeric(12,2) NOT NULL,
  name text NOT NULL
);
INSERT INTO account_move(partner_id, amount, name) VALUES
  (1, 100.00, 'INV/001'),
  (1, 250.50, 'INV/002'),
  (2, 40.00, 'INV/003');

CREATE TABLE ir_attachment (
  id serial PRIMARY KEY,
  name text NOT NULL,
  store_fname text NOT NULL,
  checksum text NOT NULL,
  res_model text,
  res_id int
);
INSERT INTO ir_attachment(name, store_fname, checksum, res_model, res_id) VALUES
  ('doc1.bin', 'attachments/doc1.bin', '${fs_sum}', 'account.move', 1);
SQL
  fi
}

soviez_test_pg_invariant() {
  local db="$1"
  if [[ -n "${SOVIEZ_TEST_PG_CONTAINER:-}" ]]; then
    docker exec -e PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD" "$SOVIEZ_TEST_PG_CONTAINER" \
      psql -At -U "$SOVIEZ_TEST_PG_USER" -d "$db" -c \
      "SELECT 'uuid='||value FROM ir_config_parameter WHERE key='database.uuid'
       UNION ALL SELECT 'partners='||count(*)::text FROM res_partner
       UNION ALL SELECT 'moves='||count(*)::text FROM account_move
       UNION ALL SELECT 'atts='||count(*)::text FROM ir_attachment
       UNION ALL SELECT 'sum='||coalesce(sum(amount),0)::text FROM account_move
       ORDER BY 1;"
  else
    export PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD"
    psql -At -h "$SOVIEZ_TEST_PG_HOST" -p "$SOVIEZ_TEST_PG_PORT" -U "$SOVIEZ_TEST_PG_USER" -d "$db" -c \
      "SELECT 'uuid='||value FROM ir_config_parameter WHERE key='database.uuid'
       UNION ALL SELECT 'partners='||count(*)::text FROM res_partner
       UNION ALL SELECT 'moves='||count(*)::text FROM account_move
       UNION ALL SELECT 'atts='||count(*)::text FROM ir_attachment
       UNION ALL SELECT 'sum='||coalesce(sum(amount),0)::text FROM account_move
       ORDER BY 1;"
  fi
}

soviez_test_pg_q() {
  local db="$1"; shift
  if [[ -n "${SOVIEZ_TEST_PG_CONTAINER:-}" ]]; then
    docker exec -e PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD" "$SOVIEZ_TEST_PG_CONTAINER" \
      psql -At -U "$SOVIEZ_TEST_PG_USER" -d "$db" -c "$*"
  else
    PGPASSWORD="$SOVIEZ_TEST_PG_PASSWORD" psql -At \
      -h "$SOVIEZ_TEST_PG_HOST" -p "$SOVIEZ_TEST_PG_PORT" -U "$SOVIEZ_TEST_PG_USER" -d "$db" -c "$*"
  fi
}
