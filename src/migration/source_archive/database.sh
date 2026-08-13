# shellcheck shell=bash

soviez_migration_p22_archive_database() {
  local op_id="$1"
  local out_dir out_file db_name require_real real_pg=0
  out_dir="$(soviez_migration_p22_archive_op_dir "$op_id")/database"
  mkdir -p "$out_dir"
  out_file="$out_dir/dump.fc"
  db_name="${SOVIEZ_MIG_P22_SOURCE_DB_NAME:-${SOVIEZ_MIG_SOURCE_DB_NAME:-soviez_src}}"
  require_real="${SOVIEZ_MIG_P22_REQUIRE_REAL_PG:-0}"

  if [[ -n "${SOVIEZ_MIG_PG_DUMP_CID:-}" ]] && command -v docker >/dev/null 2>&1; then
    docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "${SOVIEZ_MIG_PG_DUMP_CID}" \
      pg_dump -Fc -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$db_name" > "$out_file" || \
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "pg_dump -Fc failed"
    real_pg=1
  elif [[ "$require_real" != "1" && -n "${SOVIEZ_MIG_FIXTURE_DB_DUMP:-}" && -f "${SOVIEZ_MIG_FIXTURE_DB_DUMP}" ]]; then
    # Synthetic/pinned copy allowed only when real PG is not required.
    cp -f "$SOVIEZ_MIG_FIXTURE_DB_DUMP" "$out_file"
  elif command -v pg_dump >/dev/null 2>&1 && [[ -n "${SOVIEZ_MIG_P22_PG_DSN:-}" ]]; then
    pg_dump -Fc "$SOVIEZ_MIG_P22_PG_DSN" -f "$out_file" || \
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "pg_dump failed"
    real_pg=1
  elif command -v pg_dump >/dev/null 2>&1 && \
       { command -v psql >/dev/null 2>&1; } && \
       psql -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$db_name" -c 'SELECT 1' >/dev/null 2>&1; then
    pg_dump -Fc -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$db_name" -f "$out_file" || \
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "pg_dump -Fc failed"
    real_pg=1
  elif [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "$require_real" != "1" ]]; then
    # Synthetic PGDMP only when REQUIRE_REAL_PG is unset/0 (unit paths without postgres).
    printf 'PGDMP\x01soviez-p22-fixture\n' > "$out_file"
    printf 'CREATE TABLE p22_archive_probe(id int primary key, v text);\nINSERT INTO p22_archive_probe VALUES (1, '\''ok'\'');\n' > "$out_dir/dump.sql"
  else
    if [[ "$require_real" == "1" ]]; then
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED \
        "SOVIEZ_MIG_P22_REQUIRE_REAL_PG=1 requires real pg_dump -Fc (synthetic PGDMP forbidden)"
    fi
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "no postgres dump capability"
  fi

  if [[ "$require_real" == "1" && "$real_pg" -ne 1 ]]; then
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED \
      "SOVIEZ_MIG_P22_REQUIRE_REAL_PG=1 forbids synthetic/header-only dump"
  fi

  local digest size
  digest="$(openssl dgst -sha256 "$out_file" | awk '{print $NF}')"
  size="$(wc -c < "$out_file" | tr -d ' ')"
  SOVIEZ_OUT="$out_dir/meta.json" SOVIEZ_D="$digest" SOVIEZ_S="$size" SOVIEZ_DB="$db_name" \
  SOVIEZ_REAL="$real_pg" python3 - <<'PY'
import json, os, datetime
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "database_name": os.environ["SOVIEZ_DB"],
  "path": "dump.fc",
  "sha256": os.environ["SOVIEZ_D"],
  "size_bytes": int(os.environ["SOVIEZ_S"]),
  "format": "custom",
  "real_pg_dump": os.environ["SOVIEZ_REAL"] == "1",
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
