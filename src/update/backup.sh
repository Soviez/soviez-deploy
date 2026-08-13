# shellcheck shell=bash

soviez_update_backup_create() {
  local op_id="$1" prod_json="$2"
  local bdir
  bdir="$(soviez_update_backup_dir "$op_id")"
  mkdir -p "$bdir/db" "$bdir/filestore" "$bdir/config"
  chmod 700 "$bdir"

  # Refuse backup destination inside candidate workspace
  local cdir
  cdir="$(soviez_update_candidate_dir "$op_id")"
  case "$bdir" in
    "$cdir"|"$cdir"/*) soviez_update_die UPDATE_BACKUP_FAILED "Backup destination must be outside candidate workspace" ;;
  esac

  local db_path fs_path tenant_id digest db_uuid
  tenant_id="$(soviez_json_get "$prod_json" tenant_id)"
  digest="$(soviez_json_get "$prod_json" current_digest 2>/dev/null || soviez_json_get "$prod_json" image_digest 2>/dev/null || echo unknown)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid)"
  db_path="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || true)"

  # Database backup (dump file or copy fixture dir)
  if [[ -n "$db_path" && -e "$db_path" ]]; then
    if [[ -d "$db_path" ]]; then
      cp -a "$db_path/." "$bdir/db/" || soviez_update_die UPDATE_BACKUP_FAILED "Database copy failed"
    else
      cp -a "$db_path" "$bdir/db/dump.sql" || soviez_update_die UPDATE_BACKUP_FAILED "Database dump copy failed"
    fi
  else
    # Fixture DB content
    printf 'db_uuid=%s\ntenant=%s\nfixture=1\n' "$db_uuid" "$tenant_id" > "$bdir/db/dump.sql"
  fi

  if [[ -n "$fs_path" && -e "$fs_path" ]]; then
    mkdir -p "$bdir/filestore"
    cp -a "$fs_path/." "$bdir/filestore/" 2>/dev/null || cp -a "$fs_path" "$bdir/filestore/data" \
      || soviez_update_die UPDATE_BACKUP_FAILED "Filestore backup failed"
  else
    mkdir -p "$bdir/filestore"
    printf 'filestore-marker\n' > "$bdir/filestore/.marker"
  fi

  # Runtime/config without private keys
  printf '%s\n' "$prod_json" > "$bdir/config/production_identity.json"
  printf 'digest=%s\n' "$digest" > "$bdir/config/current_digest.txt"
  printf 'db_uuid=%s\n' "$db_uuid" > "$bdir/config/database_uuid.txt"
  # Nginx routing reference (no private keys)
  local nginx_ref
  nginx_ref="$(soviez_json_get "$prod_json" nginx_config_ref 2>/dev/null || echo none)"
  printf 'nginx_ref=%s\ncert_ref=%s\n' "$nginx_ref" "$(soviez_json_get "$prod_json" cert_ref 2>/dev/null || echo none)" \
    > "$bdir/config/routing_refs.txt"

  # Checksums (stable tree hash via openssl stdin)
  local db_sum fs_sum
  db_sum="$(find "$bdir/db" -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do cat "$f"; done | openssl dgst -sha256 | awk '{print $NF}')"
  fs_sum="$(find "$bdir/filestore" -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do cat "$f"; done | openssl dgst -sha256 | awk '{print $NF}')"
  [[ -n "$db_sum" ]] || db_sum=none
  [[ -n "$fs_sum" ]] || fs_sum=none
  printf 'db=%s\nfs=%s\n' "$db_sum" "$fs_sum" > "$bdir/checksums.txt"

  local manifest
  manifest="$(SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_D="$digest" SOVIEZ_U="$db_uuid" \
    SOVIEZ_DBS="$db_sum" SOVIEZ_FSS="$fs_sum" SOVIEZ_NOW="$(soviez_utc_now)" python3 - <<'PY'
import json,os
print(json.dumps({
  "operation_id":os.environ["SOVIEZ_OP"],
  "tenant_id":os.environ["SOVIEZ_T"],
  "database_uuid":os.environ["SOVIEZ_U"],
  "previous_digest":os.environ["SOVIEZ_D"],
  "created_at":os.environ["SOVIEZ_NOW"],
  "checksums":{"db":os.environ["SOVIEZ_DBS"],"filestore":os.environ["SOVIEZ_FSS"]},
  "components":["db","filestore","config","digest","database_uuid","routing_refs","rollback_manifest"],
  "safety_window_hours":int(os.environ.get("SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS") or "24"),
},separators=(",",":")))
PY
)"
  printf '%s' "$manifest" > "$(soviez_update_rollback_manifest "$op_id")"
  printf '%s' "$manifest" > "$bdir/recovery_set.json"
  printf '%s' "$manifest"
}

soviez_update_backup_verify() {
  local op_id="$1"
  local bdir man
  bdir="$(soviez_update_backup_dir "$op_id")"
  man="$(soviez_update_rollback_manifest "$op_id")"
  [[ -f "$man" ]] || soviez_update_die UPDATE_ROLLBACK_SET_INCOMPLETE "Missing rollback manifest"
  [[ -d "$bdir/db" ]] || soviez_update_die UPDATE_BACKUP_INVALID "Missing database backup"
  [[ -d "$bdir/filestore" ]] || soviez_update_die UPDATE_BACKUP_INVALID "Missing filestore backup"
  [[ -f "$bdir/config/production_identity.json" ]] || soviez_update_die UPDATE_ROLLBACK_SET_INCOMPLETE "Missing identity"
  [[ -f "$bdir/checksums.txt" ]] || soviez_update_die UPDATE_BACKUP_INVALID "Missing checksums"
  local expected actual
  expected="$(awk -F= '/^db=/{print $2}' "$bdir/checksums.txt")"
  actual="$(find "$bdir/db" -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do cat "$f"; done | openssl dgst -sha256 | awk '{print $NF}')"
  [[ -n "$actual" ]] || actual=none
  [[ "$expected" == "$actual" ]] || soviez_update_die UPDATE_BACKUP_INCONSISTENT "Database backup checksum mismatch"
  if [[ "${SOVIEZ_UPDATE_FIXTURE_CORRUPT_BACKUP:-0}" == "1" ]]; then
    soviez_update_die UPDATE_BACKUP_INVALID "Injected backup corruption"
  fi
}
