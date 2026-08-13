# shellcheck shell=bash

soviez_migration_database_dump() {
  local pair_id="$1" op_id="$2"
  local inv db_name out_dir out_file
  soviez_migration_paths_init
  if declare -F soviez_phase19_assert_cert_gates >/dev/null 2>&1; then
    soviez_phase19_assert_cert_gates
  fi
  inv="$(soviez_migration_database_inventory "$pair_id")"
  db_name="$(soviez_json_get "$inv" database_name)"
  [[ -n "$db_name" && "$db_name" != "null" ]] || db_name="${SOVIEZ_MIG_SOURCE_DB_NAME:-soviez_src}"
  out_dir="$(soviez_migration_transfer_op_dir "$op_id")/database"
  mkdir -p "$out_dir"
  out_file="$out_dir/dump.fc"

  local require_real=0
  if [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES:-0}" == "1" || "${SOVIEZ_PHASE19_FORBID_FIXTURE_DB:-0}" == "1" ]]; then
    require_real=1
  fi
  if [[ "$require_real" == "1" && "${SOVIEZ_MIG_FORCE_FIXTURE_DB:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "fixture DB dump forbidden in certification"
  fi

  if [[ -n "${SOVIEZ_MIG_PG_DUMP_CID:-}" ]] && command -v docker >/dev/null 2>&1; then
    # Real pg_dump -Fc from exact DB; password via env only (never argv)
    docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "${SOVIEZ_MIG_PG_DUMP_CID}" \
      pg_dump -Fc -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$db_name" > "$out_file" || \
      soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "pg_dump -Fc failed"
  elif [[ -n "${SOVIEZ_MIG_FIXTURE_DB_DUMP:-}" && -f "${SOVIEZ_MIG_FIXTURE_DB_DUMP}" ]]; then
    # Pre-produced dump (must be real PGDMP when certification requires real postgres)
    if [[ "$require_real" == "1" ]]; then
      if ! head -c 5 "${SOVIEZ_MIG_FIXTURE_DB_DUMP}" | grep -q 'PGDMP'; then
        soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "certification requires real PGDMP dump file"
      fi
    fi
    cp -f "$SOVIEZ_MIG_FIXTURE_DB_DUMP" "$out_file"
  elif [[ "$require_real" == "1" ]]; then
    soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "SOVIEZ_MIG_PG_DUMP_CID or real SOVIEZ_MIG_FIXTURE_DB_DUMP required"
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" || "${SOVIEZ_MIG_TRANSFER_LOCAL:-0}" == "1" ]]; then
    printf 'PGDMP\x00\x01FIXTURE' > "$out_file"
  else
    if declare -F soviez_backup_pg_dump_fc >/dev/null 2>&1; then
      soviez_backup_pg_dump_fc "$db_name" "$out_file" || \
        soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "pg_dump -Fc failed"
    elif command -v pg_dump >/dev/null 2>&1; then
      pg_dump -Fc -d "$db_name" -f "$out_file" || \
        soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "pg_dump failed"
    else
      soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "pg_dump not available"
    fi
  fi

  # Reject fixture magic header in certification
  if [[ "$require_real" == "1" ]]; then
    if ! head -c 5 "$out_file" | grep -q 'PGDMP'; then
      soviez_migration_die MIGRATION_DATABASE_VERIFY_FAILED "dump missing PGDMP header"
    fi
    if grep -aq 'FIXTURE' "$out_file" 2>/dev/null && [[ "$(wc -c < "$out_file" | tr -d ' ')" -lt 64 ]]; then
      soviez_migration_die MIGRATION_DATABASE_DUMP_FAILED "fixture dump blob rejected"
    fi
  fi

  local digest size
  digest="$(openssl dgst -sha256 "$out_file" | awk '{print $NF}')"
  size="$(wc -c < "$out_file" | tr -d ' ')"
  SOVIEZ_OUT="$out_dir/dump_meta.json" SOVIEZ_D="$digest" SOVIEZ_S="$size" SOVIEZ_DB="$db_name" python3 - <<'PY'
import json, os, datetime
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "database_name": os.environ["SOVIEZ_DB"],
  "path": "dump.fc",
  "sha256": os.environ["SOVIEZ_D"],
  "size_bytes": int(os.environ["SOVIEZ_S"]),
  "format": "custom",
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
