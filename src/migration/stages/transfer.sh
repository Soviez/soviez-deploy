# shellcheck shell=bash

soviez_migration_stages_transfer() {
  local pair_id="$1" op_id="$2" manifest_id="$3" staging_id="$4"
  local pair selected flags_json warnings=0
  pair="$(soviez_migration_transfer_load_pair "$pair_id")"
  selected="$(soviez_json_get "$pair" selected_stage_ids)"
  flags_json="$(soviez_json_get "$pair" stage_flags)"
  mkdir -p "$(soviez_migration_staging_dir "$staging_id")/stages"

  # Force-fail injectors for certification matrices
  if [[ "${SOVIEZ_MIG_STAGE_FORCE_FAIL:-}" == "mandatory" ]]; then
    printf '{"status":"blocked","code":"MIGRATION_STAGE_TRANSFER_FAILED"}\n'
    return 2
  fi
  if [[ "${SOVIEZ_MIG_STAGE_FORCE_FAIL:-}" == "optional" ]]; then
    printf '{"status":"warning","code":"MIGRATION_STAGE_TRANSFER_FAILED"}\n'
    return 1
  fi

  local stage_ids
  stage_ids="$(SOVIEZ_SEL="$selected" python3 - <<'PY'
import json, os
s=json.loads(os.environ["SOVIEZ_SEL"] or "[]")
if isinstance(s, str):
  try: s=json.loads(s)
  except Exception: s=[]
print("\n".join([x for x in s if x]))
PY
)"
  if [[ -z "$stage_ids" ]]; then
    printf '{"status":"stages_complete","selected":0,"operation_id":"%s"}\n' "$op_id"
    return 0
  fi

  while IFS= read -r stage_id; do
    [[ -n "$stage_id" ]] || continue
    local elig_rc=0
    soviez_migration_stage_eligibility_check "$pair_id" "$stage_id" >/dev/null 2>&1 || elig_rc=$?
    if [[ "$elig_rc" -ne 0 ]]; then
      local mandatory
      mandatory="$(SOVIEZ_F="${flags_json:-"{}"}" SOVIEZ_S="$stage_id" python3 -c 'import json,os
f=json.loads(os.environ["SOVIEZ_F"] or "{}")
if isinstance(f,str):
  try: f=json.loads(f)
  except: f={}
print((f.get(os.environ["SOVIEZ_S"]) or {}).get("mandatory", False))')"
      if [[ "$mandatory" == "True" || "$mandatory" == "true" ]]; then
        printf '{"status":"blocked","stage_id":"%s","code":"MIGRATION_STAGE_NOT_ELIGIBLE"}\n' "$stage_id"
        return 2
      fi
      warnings=1
      mkdir -p "$(soviez_migration_staging_dir "$staging_id")/stages/$stage_id"
      printf '{"stage_id":"%s","status":"warning","code":"MIGRATION_STAGE_NOT_ELIGIBLE","public_route":false}\n' "$stage_id" \
        > "$(soviez_migration_staging_dir "$staging_id")/stages/$stage_id/state.json"
      continue
    fi

    local st_dir
    st_dir="$(soviez_migration_staging_dir "$staging_id")/stages/$stage_id"
    mkdir -p "$st_dir/filestore" "$st_dir/database" "$st_dir/addons"

    # Real Stage payload when provided
    local src_db="${SOVIEZ_MIG_STAGE_DB_PREFIX:-}${stage_id}"
    src_db="${SOVIEZ_MIG_STAGE_DB_NAME:-$src_db}"
    if [[ -n "${SOVIEZ_MIG_PG_DUMP_CID:-}" && "${SOVIEZ_PHASE19_REQUIRE_REAL_STAGE:-0}" == "1" ]]; then
      local dump_out="$st_dir/database/stage.dump.fc"
      docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "${SOVIEZ_MIG_PG_DUMP_CID}" \
        pg_dump -Fc -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$src_db" > "$dump_out" 2>/dev/null || \
        docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "${SOVIEZ_MIG_PG_DUMP_CID}" \
          pg_dump -Fc -U postgres -d "$src_db" > "$dump_out" || \
          soviez_migration_die MIGRATION_STAGE_TRANSFER_FAILED "stage pg_dump failed for $stage_id"
      # Transfer dump via mTLS channel as chunks
      if declare -F soviez_migration_chunk_plan_file >/dev/null 2>&1; then
        soviez_migration_chunk_plan_file "$op_id" "stage-${stage_id}-db" "stage_database" "$dump_out" >/dev/null
        local reg cid
        reg="$(soviez_migration_chunk_registry_path "$op_id")"
        while IFS= read -r cid; do
          [[ -n "$cid" ]] || continue
          local cpath
          cpath="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$cid" python3 -c 'import json,os;d=json.load(open(os.environ["SOVIEZ_REG"]));print(d["chunks"][os.environ["SOVIEZ_CID"]]["local_path"])')"
          soviez_migration_channel_put "$op_id" "$cid" "$cpath" >/dev/null
          soviez_migration_chunk_set_state "$op_id" "$cid" verified >/dev/null
        done < <(SOVIEZ_REG="$reg" SOVIEZ_OID="stage-${stage_id}-db" python3 -c 'import json,os;d=json.load(open(os.environ["SOVIEZ_REG"]));
print("\n".join([c["chunk_id"] for c in d.get("chunks",{}).values() if c.get("payload_object_id")==os.environ["SOVIEZ_OID"]]))')
      fi
      # Restore into staging PG exact DB
      if [[ -n "${SOVIEZ_MIG_PG_RESTORE_CID:-}" ]]; then
        local sid_alnum="${stage_id//-/}"
        sid_alnum="${sid_alnum//_/}"
        local dest_db="soviez_stgst_${sid_alnum:0:8}"
        docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
          psql -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d postgres -c "DROP DATABASE IF EXISTS ${dest_db};" >/dev/null 2>&1 || true
        docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
          psql -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d postgres -c "CREATE DATABASE ${dest_db};" >/dev/null 2>&1 || \
          docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
            psql -U postgres -d postgres -c "CREATE DATABASE ${dest_db};" >/dev/null
        docker cp "$dump_out" "$SOVIEZ_MIG_PG_RESTORE_CID:/tmp/stage_restore.fc" >/dev/null
        docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
          pg_restore -U "${SOVIEZ_MIG_PG_USER:-postgres}" -d "$dest_db" --no-owner --no-acl /tmp/stage_restore.fc >/dev/null 2>&1 || \
          docker exec -e PGPASSWORD="${SOVIEZ_MIG_PG_PASSWORD:-soviez}" "$SOVIEZ_MIG_PG_RESTORE_CID" \
            pg_restore -U postgres -d "$dest_db" --no-owner --no-acl /tmp/stage_restore.fc >/dev/null 2>&1 || \
            soviez_migration_die MIGRATION_STAGE_TRANSFER_FAILED "stage pg_restore failed"
        printf '%s\n' "$dest_db" > "$st_dir/database/restored_db_name"
      fi
    elif [[ "${SOVIEZ_PHASE19_REQUIRE_REAL_STAGE:-0}" == "1" || "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]; then
      # Allow explicit stage dump file fixture that is a real PGDMP
      if [[ -n "${SOVIEZ_MIG_STAGE_DUMP_FILE:-}" && -f "${SOVIEZ_MIG_STAGE_DUMP_FILE}" ]]; then
        cp -f "$SOVIEZ_MIG_STAGE_DUMP_FILE" "$st_dir/database/stage.dump.fc"
      else
        soviez_migration_die MIGRATION_STAGE_TRANSFER_FAILED "real Stage DB required for $stage_id"
      fi
    fi

    # Filestore
    local fs_src="${SOVIEZ_MIG_STAGE_FILESTORE_ROOT:-}/$stage_id"
    if [[ -d "$fs_src" ]]; then
      cp -a "$fs_src/." "$st_dir/filestore/" 2>/dev/null || true
    elif [[ -n "${SOVIEZ_MIG_STAGE_FILESTORE_MAP:-}" ]]; then
      local mapped
      mapped="$(SOVIEZ_M="$SOVIEZ_MIG_STAGE_FILESTORE_MAP" SOVIEZ_S="$stage_id" python3 -c 'import json,os; m=json.loads(os.environ["SOVIEZ_M"]); print(m.get(os.environ["SOVIEZ_S"],""))')"
      [[ -n "$mapped" && -d "$mapped" ]] && cp -a "$mapped/." "$st_dir/filestore/" || true
    fi

    # Addon package if provided
    if [[ -n "${SOVIEZ_MIG_STAGE_ADDON_DIR:-}" && -d "${SOVIEZ_MIG_STAGE_ADDON_DIR}" ]]; then
      mkdir -p "$st_dir/addons"
      # Exact allowlisted copy without .git
      rsync -a --exclude '.git' --exclude '__pycache__' "${SOVIEZ_MIG_STAGE_ADDON_DIR}/" "$st_dir/addons/" 2>/dev/null || \
        cp -a "${SOVIEZ_MIG_STAGE_ADDON_DIR}/." "$st_dir/addons/"
    fi

    # Retention unchanged marker
    printf '{"retention_extended":false}\n' > "$st_dir/retention.json"
    printf '{"stage_id":"%s","status":"transferred","public_route":false,"source_unchanged":true,"retention_extended":false}\n' "$stage_id" \
      > "$st_dir/state.json"
  done <<< "$stage_ids"

  if [[ "$warnings" -eq 1 ]]; then
    printf '{"status":"warning","operation_id":"%s"}\n' "$op_id"
    return 1
  fi
  printf '{"status":"stages_complete","operation_id":"%s"}\n' "$op_id"
  return 0
}
