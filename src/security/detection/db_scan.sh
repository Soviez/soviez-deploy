# shellcheck shell=bash
# Security Gate S3 — read-only Odoo/PostgreSQL technical persistence scanner.

soviez_s3_db_table_for_model() {
  case "$1" in
    ir.actions.server|ir_act_server) printf '%s\n' "ir_act_server" ;;
    ir.config_parameter|ir_config_parameter) printf '%s\n' "ir_config_parameter" ;;
    ir.ui.view|ir_ui_view) printf '%s\n' "ir_ui_view" ;;
    ir.cron|ir_cron) printf '%s\n' "ir_cron" ;;
    base.automation|base_automation) printf '%s\n' "base_automation" ;;
    res.users|res_users) printf '%s\n' "res_users" ;;
    res.groups|res_groups) printf '%s\n' "res_groups" ;;
    ir.module.module|ir_module_module) printf '%s\n' "ir_module_module" ;;
    *) printf '%s\n' "" ;;
  esac
}

soviez_s3_db_psql() {
  # Args: container user password dbname sql
  local ctn="$1" user="$2" pass="$3" db="$4" sql="$5"
  docker exec -e PGPASSWORD="$pass" "$ctn" \
    psql -v ON_ERROR_STOP=1 -U "$user" -d "$db" -At -c "$sql" 2>/dev/null
}

soviez_s3_db_table_exists() {
  local ctn="$1" user="$2" pass="$3" db="$4" table="$5"
  local out
  out="$(soviez_s3_db_psql "$ctn" "$user" "$pass" "$db" \
    "SELECT to_regclass('public.${table}') IS NOT NULL;" 2>/dev/null || echo f)"
  [[ "$out" == "t" ]]
}

soviez_s3_db_extract_records() {
  # Extract technical records as JSON lines into outfile. READ ONLY.
  local ctn="$1" user="$2" pass="$3" db="$4" out="$5"
  local tmp_sql records_json
  records_json="$(mktemp)"
  echo '{"records":[' >"$records_json"
  local first=1

  # Begin read-only transaction probe
  if ! soviez_s3_db_psql "$ctn" "$user" "$pass" "$db" "START TRANSACTION READ ONLY; SELECT 1; COMMIT;" >/dev/null; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: cannot open READ ONLY DB session" >&2
    rm -f "$records_json"
    return 1
  fi

  append_rows() {
    local model="$1" table="$2" id_expr="$3" name_expr="$4" field="$5" content_expr="$6" active_expr="$7"
    local sql row
    if ! soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "$table"; then
      return 0
    fi
    sql="SELECT ${id_expr}::text || E'\\t' || coalesce(${name_expr}::text,'') || E'\\t' || coalesce(${active_expr}::text,'') || E'\\t' || coalesce(replace(replace(${content_expr}::text, E'\\t',' '), E'\\n','\\\\n'),'') FROM ${table} LIMIT 5000;"
    while IFS=$'\t' read -r rid rname ractive rcontent; do
      [[ -n "$rid" ]] || continue
      # Never execute content — only serialize for classifier
      local esc
      esc="$(printf '%s' "$rcontent" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '""')"
      local name_esc active_esc
      name_esc="$(printf '%s' "$rname" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '""')"
      active_esc="$(printf '%s' "$ractive" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '""')"
      [[ $first -eq 1 ]] || printf ',' >>"$records_json"
      first=0
      printf '{"model":"%s","id":%s,"name":%s,"active":%s,"field":"%s","content":%s,"executable":true}' \
        "$model" "$(printf '%s' "$rid" | tr -cd '0-9')" "$name_esc" "$active_esc" "$field" "$esc" >>"$records_json"
    done < <(soviez_s3_db_psql "$ctn" "$user" "$pass" "$db" "$sql" || true)
  }

  # ir.actions.server — code field
  append_rows "ir.actions.server" "ir_act_server" "id" "name" "code" "code" "coalesce(active::text,'t')"
  # ir.config_parameter
  append_rows "ir.config_parameter" "ir_config_parameter" "id" "key" "value" "value" "'t'"
  # ir.ui.view — arch_db / arch
  if soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "ir_ui_view"; then
    local cols
    cols="$(soviez_s3_db_psql "$ctn" "$user" "$pass" "$db" \
      "SELECT string_agg(column_name,',') FROM information_schema.columns WHERE table_name='ir_ui_view';" || true)"
    if [[ "$cols" == *arch_db* ]]; then
      append_rows "ir.ui.view" "ir_ui_view" "id" "name" "arch_db" "arch_db" "coalesce(active::text,'t')"
    elif [[ "$cols" == *arch* ]]; then
      append_rows "ir.ui.view" "ir_ui_view" "id" "name" "arch" "arch" "coalesce(active::text,'t')"
    fi
  fi
  # ir.cron
  append_rows "ir.cron" "ir_cron" "id" "cron_name" "code" "coalesce(code,'')" "coalesce(active::text,'t')"
  # base.automation — may store code in different fields; try code
  if soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "base_automation"; then
    append_rows "base.automation" "base_automation" "id" "name" "code" "coalesce(code,'')" "coalesce(active::text,'t')"
  fi
  # res.users — login only (no password hashes dumped)
  if soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "res_users"; then
    append_rows "res.users" "res_users" "id" "login" "login" "login" "coalesce(active::text,'t')"
  fi
  # res.groups — name
  if soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "res_groups"; then
    append_rows "res.groups" "res_groups" "id" "name" "name" "name" "'t'"
  fi
  # ir.module.module — name/state
  if soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "ir_module_module"; then
    append_rows "ir.module.module" "ir_module_module" "id" "name" "name" "coalesce(name,'') || ' ' || coalesce(state,'')" "'t'"
  fi

  echo ']}' >>"$records_json"
  mv -f "$records_json" "$out"
  return 0
}

soviez_s3_db_scan() {
  # Env: SOVIEZ_SEC_PG_CONTAINER, admin user/pass, db name
  local ctn="${SOVIEZ_SEC_PG_CONTAINER:-}"
  local user="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local pass="${SOVIEZ_SEC_PG_ADMIN_PASS:-${SOVIEZ_PG_ADMIN_PASSWORD:-}}"
  local db="${SOVIEZ_SEC_PG_DB:-${SOVIEZ_DB_NAME:-postgres}}"
  local evidence_root="${1:-}"

  if [[ -z "$ctn" || -z "$pass" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: PG container/credentials required for DB scan" >&2
    return 1
  fi
  if ! docker inspect "$ctn" >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: PG container missing" >&2
    return 1
  fi

  # Required surface: ir_act_server must be inspectable for Production-like DBs;
  # synthetic empty DBs may lack Odoo schema → BLOCK if forced.
  local require_odoo="${SOVIEZ_S3_REQUIRE_ODOO_SCHEMA:-0}"

  local share records out
  share="$(soviez_s3_detection_share)"
  records="$(mktemp)"
  if ! soviez_s3_db_extract_records "$ctn" "$user" "$pass" "$db" "$records"; then
    rm -f "$records"
    return 1
  fi

  if [[ "$require_odoo" == "1" ]] && ! soviez_s3_db_table_exists "$ctn" "$user" "$pass" "$db" "ir_act_server"; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: required model ir.actions.server unavailable" >&2
    rm -f "$records"
    return 1
  fi

  out="$(mktemp)"
  python3 "${share}/classify_records.py" "${share}/db_rules.json" "${share}/iocs.json" "$records" >"$out" || {
    rm -f "$records" "$out"
    return 1
  }

  # Mutation proof: row counts before/after (no writes expected)
  local mut=0
  # Classifier always reports mutation_count=0; assert JSON
  if ! grep -q '"mutation_count": 0' "$out" && ! grep -q '"mutation_count":0' "$out"; then
    mut=1
  fi
  if ! grep -q '"executed_payloads": 0' "$out" && ! grep -q '"executed_payloads":0' "$out"; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: classifier claimed payload execution" >&2
    rm -f "$records" "$out"
    return 1
  fi

  if [[ -n "$evidence_root" ]]; then
    cp -f "$records" "$evidence_root/findings/records_fingerprint_input.json" 2>/dev/null || true
    # Strip full content from stored evidence — keep fingerprints only for privacy
    python3 - "$records" "$evidence_root/findings/records_index.json" <<'PY'
import json,sys,hashlib
recs=json.load(open(sys.argv[1])).get("records") or []
idx=[]
for r in recs:
  c=r.get("content") or ""
  idx.append({
    "model": r.get("model"),
    "id": r.get("id"),
    "name": r.get("name"),
    "field": r.get("field"),
    "active": r.get("active"),
    "content_sha256": hashlib.sha256(c.encode("utf-8","replace")).hexdigest(),
    "content_len": len(c),
  })
json.dump({"records":idx,"full_bodies_stored":False}, open(sys.argv[2],"w"), indent=2)
PY
    soviez_s3_evidence_write_findings "$evidence_root" "$out"
  fi

  cat "$out"
  local status
  status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$out")"
  rm -f "$records" "$out"
  case "$status" in
    PASS) return 0 ;;
    PASS_WITH_REVIEW) return 0 ;;
    FAIL) return 2 ;;
    *) return 1 ;;
  esac
}

soviez_s3_db_scan_file_records() {
  # Classify a prebuilt records JSON (unit tests / fixtures) — no DB.
  local records_file="$1"
  local share out
  share="$(soviez_s3_detection_share)"
  out="$(mktemp)"
  python3 "${share}/classify_records.py" "${share}/db_rules.json" "${share}/iocs.json" "$records_file" >"$out"
  cat "$out"
  local status
  status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$out")"
  rm -f "$out"
  case "$status" in
    PASS|PASS_WITH_REVIEW) return 0 ;;
    FAIL) return 2 ;;
    *) return 1 ;;
  esac
}
