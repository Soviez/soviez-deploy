# shellcheck shell=bash
# Stage lifecycle: list/status/start/stop/backup/drop (no entitlement required).

soviez_stage_cmd_list() {
  soviez_stage_paths_init
  local ids
  if ! ids="$(soviez_stage_inventory_list_ids)"; then
    # Corrupt inventory: clean message already printed; no traceback.
    return 2
  fi
  echo "Stage ID | Domain | Status | Parent | Created | Cert"
  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local ident domain status parent created cert
    ident="$(soviez_stage_inventory_find "$id" 2>/dev/null || true)"
    [[ -n "$ident" ]] || continue
    domain="$(soviez_json_get "$ident" stage_domain 2>/dev/null || echo "-")"
    status="$(soviez_json_get "$ident" lifecycle_status 2>/dev/null || echo unknown)"
    parent="$(soviez_json_get "$ident" parent_production_tenant_id 2>/dev/null || echo "-")"
    created="$(soviez_json_get "$ident" created_at 2>/dev/null || echo "-")"
    cert="$(soviez_json_get "$ident" origin_certificate_path 2>/dev/null || echo none)"
    [[ -n "$cert" && "$cert" != "null" && -f "$cert" ]] && cert="valid" || cert="missing"
    printf '%s | %s | %s | %s | %s | %s\n' "$id" "$domain" "$status" "$parent" "$created" "$cert"
  done <<<"$ids"
}

soviez_stage_cmd_status() {
  local stage_id="$1"
  soviez_stage_paths_init
  stage_id="$(soviez_stage_sanitize_id "$stage_id")" || soviez_stage_die STAGE_ID_CONFLICT "Invalid stage id"
  local ident
  ident="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage: $stage_id"
  printf '%s\n' "$ident"
}

soviez_stage_cmd_start() {
  local stage_id="$1"
  soviez_stage_paths_init
  soviez_stage_runtime_start "$stage_id"
  echo "Started stage $stage_id"
}

soviez_stage_cmd_stop() {
  local stage_id="$1"
  soviez_stage_paths_init
  soviez_stage_runtime_stop "$stage_id"
  echo "Stopped stage $stage_id"
}

soviez_stage_cmd_backup() {
  local stage_id="$1"
  if declare -F soviez_backup_stage_live_backup >/dev/null 2>&1; then
    soviez_backup_stage_live_backup "$stage_id"
    return $?
  fi
  # Fallback if backup engine not assembled yet
  soviez_stage_paths_init
  local ident
  ident="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage"
  local backup_root="${SOVIEZ_ROOT:-/var/soviez}/backups/stages"
  mkdir -p "$backup_root"
  local ts archive
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  archive="$backup_root/${stage_id}-${ts}.tar"
  local fs db_name
  fs="$(soviez_json_get "$ident" stage_filestore_path)"
  db_name="$(soviez_json_get "$ident" stage_db_name)"
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/meta" "$tmp/filestore" "$tmp/db"
  printf '%s' "$ident" > "$tmp/meta/identity.json"
  if [[ -d "$fs" ]]; then
    cp -a "$fs"/. "$tmp/filestore/" 2>/dev/null || true
  fi
  if declare -F soviez_stage_use_live_pg >/dev/null 2>&1 && soviez_stage_use_live_pg; then
    if declare -F soviez_stage_pg_dump_fc >/dev/null 2>&1; then
      soviez_stage_pg_dump_fc "$db_name" "$tmp/db/db.dump" || true
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -d "$SOVIEZ_ROOT/stage-dbs/$db_name" ]]; then
    cp -a "$SOVIEZ_ROOT/stage-dbs/$db_name"/. "$tmp/db/"
  fi
  tar -C "$tmp" -cf "$archive" .
  local sum
  sum="$(soviez_sha256_file "$archive")"
  printf '%s' "$sum" > "${archive}.sha256"
  rm -rf "$tmp"
  echo "Backup written: $archive"
  echo "SHA256: $sum"
}

soviez_stage_cmd_drop() {
  local stage_id="$1"
  soviez_stage_paths_init
  local ident
  ident="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage"
  local domain db created parent
  domain="$(soviez_json_get "$ident" stage_domain)"
  db="$(soviez_json_get "$ident" stage_db_name)"
  created="$(soviez_json_get "$ident" created_at)"
  parent="$(soviez_json_get "$ident" parent_production_tenant_id)"

  echo "About to DROP Stage:"
  echo "  stage_id=$stage_id"
  echo "  domain=$domain"
  echo "  db=$db"
  echo "  created=$created"
  echo "  parent_production=$parent"
  echo "Production resources will NOT be modified."

  if [[ "${SOVIEZ_STAGE_DROP_CONFIRM:-}" != "$stage_id" ]]; then
    if [[ -t 0 ]]; then
      printf 'Type the Stage ID to confirm drop: ' >&2
      local typed
      read -r typed
      [[ "$typed" == "$stage_id" ]] || soviez_stage_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Confirmation mismatch"
    else
      soviez_stage_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Set SOVIEZ_STAGE_DROP_CONFIRM=$stage_id for non-TTY drop"
    fi
  fi

  # Optional backup offer
  if [[ "${SOVIEZ_STAGE_DROP_SKIP_BACKUP:-0}" != "1" ]]; then
    soviez_stage_cmd_backup "$stage_id" || true
  fi

  soviez_stage_runtime_remove_owned "$stage_id"
  rm -rf "$(soviez_stage_dir "$stage_id")"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    rm -rf "$SOVIEZ_ROOT/stage-dbs/$db"
  fi

  local new_index
  new_index="$(SOVIEZ_IDX="$(soviez_stage_inventory_load_index)" SOVIEZ_SID="$stage_id" python3 - <<'PY'
import json,os
idx=json.loads(os.environ["SOVIEZ_IDX"])
idx["stages"]=[s for s in idx.get("stages",[]) if s.get("stage_id")!=os.environ["SOVIEZ_SID"]]
print(json.dumps(idx, separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_stage_inventory_index)" "$new_index"
  echo "Dropped stage $stage_id (Production untouched)"
}
