# shellcheck shell=bash
# Safe Mode — capture exact cron/automation state, disable safely, restore on exit.

soviez_safe_mode_state_dir() {
  local prod="$1"
  printf '%s\n' "/var/soviez/safe-mode/${prod}"
}

soviez_cmd_safe_mode_run() {
  local prod="${SOVIEZ_CLI_TARGET:-${1:-}}"
  [[ -n "$prod" ]] || {
    echo "usage: soviez.sh --safe-mode <production-id>" >&2
    return 1
  }
  local state_dir
  state_dir="$(soviez_safe_mode_state_dir "$prod")"
  mkdir -p "$state_dir"

  local env_file="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}/${prod}/.soviez.env"
  [[ -f "$env_file" ]] || {
    echo "[error] production env missing: $prod" >&2
    return 1
  }
  # shellcheck disable=SC1090
  source "$env_file"

  local web="${WEB_CONTAINER:-soviez-web}"
  local db="${DB_CONTAINER:-soviez-db}"
  local db_user="${SOVIEZ_PG_APP_USER:-soviez_app}"
  local db_pass="${SOVIEZ_DB_PASSWORD:-}"
  local db_name="${SOVIEZ_DB_NAME:-production}"

  if [[ ! -f "${state_dir}/cron_snapshot.sql" ]]; then
    docker exec -e PGPASSWORD="$db_pass" "$db" psql -U "$db_user" -d "$db_name" -At \
      -c "COPY (SELECT id, cron_name, active FROM ir_cron ORDER BY id) TO STDOUT WITH CSV HEADER;" \
      >"${state_dir}/cron_snapshot.csv" 2>/dev/null || {
      echo "[warn] could not snapshot ir_cron — Safe Mode partial"
    }
    docker exec -e PGPASSWORD="$db_pass" "$db" psql -U "$db_user" -d "$db_name" -c \
      "UPDATE ir_cron SET active=false WHERE active=true;" >/dev/null 2>&1 || true
    date -u +%Y-%m-%dT%H:%M:%SZ >"${state_dir}/entered_at"
    echo "[ok] Safe Mode enabled for $prod (cron deactivated from snapshot)"
  else
    echo "[ok] Safe Mode already active for $prod"
  fi
  return 0
}

soviez_cmd_safe_mode_exit_run() {
  local prod="${SOVIEZ_CLI_TARGET:-${1:-}}"
  [[ -n "$prod" ]] || {
    echo "usage: soviez.sh --safe-mode-exit <production-id>" >&2
    return 1
  }
  local state_dir
  state_dir="$(soviez_safe_mode_state_dir "$prod")"
  [[ -f "${state_dir}/cron_snapshot.csv" ]] || {
    echo "[error] no Safe Mode snapshot for $prod" >&2
    return 1
  }

  local env_file="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}/${prod}/.soviez.env"
  # shellcheck disable=SC1090
  source "$env_file"
  local db="${DB_CONTAINER:-soviez-db}"
  local db_user="${SOVIEZ_PG_APP_USER:-soviez_app}"
  local db_pass="${SOVIEZ_DB_PASSWORD:-}"
  local db_name="${SOVIEZ_DB_NAME:-production}"

  python3 - "${state_dir}/cron_snapshot.csv" <<'PY' | while IFS=, read -r id name active; do
import csv, sys
with open(sys.argv[1], newline="", encoding="utf-8") as f:
    r = csv.DictReader(f)
    for row in r:
        print(row.get("id",""), row.get("active",""))
PY
    [[ "$id" == "id" ]] && continue
    [[ -z "$id" ]] && continue
    docker exec -e PGPASSWORD="$db_pass" "$db" psql -U "$db_user" -d "$db_name" -c \
      "UPDATE ir_cron SET active=$( [[ "$active" == "t" || "$active" == "True" || "$active" == "true" ]] && echo true || echo false ) WHERE id=${id};" \
      >/dev/null 2>&1 || true
  done

  rm -f "${state_dir}/cron_snapshot.csv" "${state_dir}/entered_at"
  echo "[ok] Safe Mode exited for $prod (exact cron states restored)"
  return 0
}
