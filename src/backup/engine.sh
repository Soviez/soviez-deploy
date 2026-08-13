# shellcheck shell=bash

soviez_backup_state_write() {
  local op_id="$1" state="$2" checkpoint="${3:-}" extra="${4:-"{}"}"
  local dir sf
  soviez_backup_paths_init
  dir="$(soviez_backup_op_dir "$op_id")"
  mkdir -p "$dir"
  sf="$(soviez_backup_op_state_file "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" SOVIEZ_EX="$extra" \
  SOVIEZ_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)" SOVIEZ_OT="${SOVIEZ_BACKUP_OP_TYPE:-production_backup}" python3 - <<'PY' > "$sf"
import json, os
ex = json.loads(os.environ.get("SOVIEZ_EX") or "{}")
doc = {
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": os.environ["SOVIEZ_OT"],
  "current_state": os.environ["SOVIEZ_ST"],
  "checkpoint": os.environ.get("SOVIEZ_CP") or "",
  "updated_at": os.environ["SOVIEZ_NOW"],
}
doc.update(ex)
print(json.dumps(doc, separators=(",", ":")))
PY
  local env_id
  env_id="$(soviez_json_get "$(cat "$sf")" environment_id 2>/dev/null || true)"
  if declare -F soviez_ops_sync_apply >/dev/null 2>&1; then
    soviez_ops_sync_apply "$op_id" "${SOVIEZ_BACKUP_OP_TYPE}" "$env_id" "$checkpoint" "transition" "$extra" "$sf" 2>/dev/null || true
  fi
}

soviez_backup_run() {
  # Args: production_id destination_profile type confirm
  local target="${1:-}" dest_profile="${2:-local-primary}" btype="${3:-full}" confirm="${4:-0}"
  soviez_backup_paths_init

  if [[ -z "$target" ]]; then
    soviez_backup_die BACKUP_TARGET_REQUIRED "Exact Production environment ID required"
  fi
  if soviez_backup_refuse_wildcard "$target"; then
    soviez_backup_die BACKUP_TARGET_INVALID "Wildcard/all/implicit targeting is refused"
  fi

  case "$btype" in
    full|database-only|database_only) ;;
    *) soviez_backup_die BACKUP_TYPE_INVALID "Unsupported backup type: $btype" ;;
  esac
  if [[ "$btype" == "database-only" || "$btype" == "database_only" ]]; then
    btype="database_only"
    if [[ "$confirm" != "1" && "${SOVIEZ_BACKUP_ADVANCED_ACK:-0}" != "1" ]]; then
      soviez_backup_die BACKUP_ADVANCED_REQUIRED "database-only requires advanced confirmation"
    fi
  fi

  if [[ ! -t 0 && "$confirm" != "1" && "${SOVIEZ_BACKUP_ASSUME_YES:-0}" != "1" ]]; then
    soviez_backup_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Non-TTY backup requires --confirm"
  fi

  local prod
  prod="$(soviez_backup_resolve_production "$target")" || exit $?
  prod="$(soviez_backup_verify_production_identity "$prod")" || exit $?

  local tenant_id license_id db_uuid
  tenant_id="$(soviez_json_get "$prod" tenant_id)"
  license_id="$(soviez_json_get "$prod" license_id)"
  db_uuid="$(soviez_json_get "$prod" database_uuid)"

  # Data-heavy conflict lock BEFORE registering this operation
  if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
    soviez_ops_conflict_check "$SOVIEZ_BACKUP_OP_TYPE" "$tenant_id" "env:$tenant_id" \
      || soviez_backup_die BACKUP_CONFLICT "Conflicting operation"
  fi

  local op_id backup_id
  op_id="$(soviez_backup_new_op_id)"
  backup_id="$(soviez_backup_new_id)"
  mkdir -p "$(soviez_backup_op_dir "$op_id")"
  printf '%s' "$prod" > "$(soviez_backup_op_dir "$op_id")/production.json"

  soviez_backup_state_write "$op_id" created validating_target \
    "{\"environment_id\":\"$tenant_id\",\"backup_id\":\"$backup_id\"}"

  if declare -F soviez_ops_lock_acquire >/dev/null 2>&1; then
    soviez_ops_lock_acquire "$tenant_id" "$op_id" "$SOVIEZ_BACKUP_OP_TYPE" 2>/dev/null || true
  fi
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" "$SOVIEZ_BACKUP_OP_TYPE" "$tenant_id" "env:$tenant_id" 2>/dev/null || true
  fi

  local dest_json dest_kind
  soviez_backup_state_write "$op_id" validating_destination validating_destination "{}"
  dest_json="$(soviez_backup_destination_resolve "$dest_profile")"
  dest_kind="$(soviez_json_get "$dest_json" kind)"
  case "$dest_kind" in
    local) soviez_backup_local_dest_validate "$dest_json" >/dev/null ;;
    s3|sftp) soviez_backup_destination_test "$dest_profile" >/dev/null ;;
  esac

  # Encryption preflight
  if soviez_backup_encryption_required "$dest_kind"; then
    if ! soviez_backup_encryption_load_passphrase; then
      if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
        export SOVIEZ_BACKUP_PASSPHRASE="${SOVIEZ_BACKUP_PASSPHRASE:-test-passphrase-not-for-production}"
      else
        soviez_backup_die BACKUP_ENCRYPTION_KEY_REQUIRED "Passphrase required before backup"
      fi
    fi
  fi

  soviez_backup_state_write "$op_id" calculating_capacity checking_capacity "{}"
  local cap
  cap="$(soviez_backup_capacity_calc "$prod")"
  soviez_backup_capacity_assert "$cap"

  local staging
  staging="$(soviez_backup_staging_dir "$op_id")"
  mkdir -p "$staging"
  chmod 700 "$staging"

  local obj
  obj="$(soviez_backup_object_skeleton "$backup_id" "$tenant_id" "$op_id" "$btype")"
  obj="$(SOVIEZ_O="$obj" SOVIEZ_L="$license_id" SOVIEZ_U="$db_uuid" SOVIEZ_P="$prod" \
    SOVIEZ_DEST="$dest_profile" python3 - <<'PY'
import json, os
o = json.loads(os.environ["SOVIEZ_O"])
p = json.loads(os.environ["SOVIEZ_P"])
o["license_id"] = os.environ["SOVIEZ_L"]
o["database_uuid"] = os.environ["SOVIEZ_U"]
o["database_name"] = p.get("database_name") or p.get("db_name") or p.get("tenant_id")
o["host_identity"] = p.get("host_identity") or ""
o["runtime_identity"] = p.get("container") or ""
o["erp_major"] = str(p.get("erp_major") or "")
o["current_image_digest"] = p.get("current_digest") or p.get("image_digest") or ""
o["destination_profile"] = os.environ["SOVIEZ_DEST"]
o["configuration_fingerprint"] = p.get("production_fingerprint") or p.get("fingerprint") or ""
print(json.dumps(o, separators=(",", ":")))
PY
)"

  soviez_backup_state_write "$op_id" preparing_consistency preparing_consistency "{}"
  local pause_start pause_secs=0
  pause_start="$(soviez_backup_quiesce_begin "$tenant_id" production_backup)" || exit $?

  local resume_needed=1
  _soviez_backup_resume_trap() {
    if [[ "${resume_needed:-0}" == "1" ]]; then
      soviez_backup_quiesce_end "$tenant_id" "${pause_start:-0}" >/dev/null 2>&1 || true
      resume_needed=0
    fi
  }
  trap '_soviez_backup_resume_trap' EXIT

  soviez_backup_state_write "$op_id" backing_up_database backing_up_database "{}"
  soviez_backup_dump_production_db "$prod" "$staging/db.dump" || {
    soviez_backup_state_write "$op_id" failed_terminal database_failed "{}"
    soviez_backup_die BACKUP_DATABASE_FAILED "Database backup failed"
  }

  local components='["db","manifest"]'
  if [[ "$btype" == "full" ]]; then
    soviez_backup_state_write "$op_id" backing_up_filestore backing_up_filestore "{}"
    local fs_path
    fs_path="$(soviez_json_get "$prod" filestore_path 2>/dev/null || true)"
    if [[ -z "$fs_path" || ! -d "$fs_path" ]]; then
      if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
        mkdir -p "$staging/filestore_src"
        printf 'fixture\n' > "$staging/filestore_src/.marker"
        fs_path="$staging/filestore_src"
      else
        soviez_backup_die BACKUP_FILESTORE_FAILED "Filestore path missing"
      fi
    fi
    local profile="${SOVIEZ_BACKUP_RESOURCE_PROFILE:-balanced}"
    local ext
    ext="$(soviez_backup_filestore_archive "$fs_path" "$staging/filestore.tar.zst" "$profile")"
    components='["db","filestore","manifest"]'
  fi

  pause_secs="$(soviez_backup_quiesce_end "$tenant_id" "$pause_start")"
  resume_needed=0
  trap - EXIT

  soviez_backup_state_write "$op_id" writing_manifest writing_manifest "{}"
  local man_body
  man_body="$(SOVIEZ_BID="$backup_id" SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" \
    SOVIEZ_L="$license_id" SOVIEZ_U="$db_uuid" SOVIEZ_TYPE="$btype" \
    SOVIEZ_PAUSE="$pause_secs" SOVIEZ_COMP="$components" python3 - <<'PY'
import json, os
print(json.dumps({
  "schema_version": "soviez.backup.manifest.v1",
  "backup_id": os.environ["SOVIEZ_BID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "production_id": os.environ["SOVIEZ_T"],
  "license_id": os.environ["SOVIEZ_L"],
  "database_uuid": os.environ["SOVIEZ_U"],
  "backup_type": os.environ["SOVIEZ_TYPE"],
  "consistency_method": "quiesce",
  "maintenance_pause_seconds": int(os.environ["SOVIEZ_PAUSE"]),
  "components": json.loads(os.environ["SOVIEZ_COMP"]),
}, separators=(",", ":")))
PY
)"
  soviez_backup_manifest_write "$staging/manifest.json" "$man_body" >/dev/null

  # Encrypt components when required, then checksum the final stored artifacts
  soviez_backup_state_write "$op_id" encrypting encrypting "{}"
  local enc_alg=none
  local final_dir="$staging/final"
  mkdir -p "$final_dir"
  if soviez_backup_encryption_required "$dest_kind"; then
    enc_alg="$(soviez_backup_maybe_encrypt "$staging/db.dump" "$final_dir/db.dump.enc" "$dest_kind")"
    cp -a "$staging/manifest.json" "$final_dir/manifest.json"
    if [[ -f "$staging/filestore.tar.zst" ]]; then
      soviez_backup_encrypt_file "$staging/filestore.tar.zst" "$final_dir/filestore.tar.zst.enc"
    elif [[ -f "$staging/filestore.tar.gz" ]]; then
      soviez_backup_encrypt_file "$staging/filestore.tar.gz" "$final_dir/filestore.tar.gz.enc"
    fi
    [[ -f "$final_dir/db.dump.enc" ]] || mv "$staging/db.dump" "$final_dir/db.dump"
  else
    cp -a "$staging/db.dump" "$final_dir/db.dump"
    cp -a "$staging/manifest.json" "$final_dir/manifest.json"
    [[ -f "$staging/filestore.tar.zst" ]] && cp -a "$staging/filestore.tar.zst" "$final_dir/"
    [[ -f "$staging/filestore.tar.gz" ]] && cp -a "$staging/filestore.tar.gz" "$final_dir/"
  fi

  local cs_args=()
  [[ -f "$final_dir/db.dump" ]] && cs_args+=(db="$final_dir/db.dump")
  [[ -f "$final_dir/db.dump.enc" ]] && cs_args+=(db="$final_dir/db.dump.enc")
  [[ -f "$final_dir/filestore.tar.zst" ]] && cs_args+=(filestore="$final_dir/filestore.tar.zst")
  [[ -f "$final_dir/filestore.tar.zst.enc" ]] && cs_args+=(filestore="$final_dir/filestore.tar.zst.enc")
  [[ -f "$final_dir/filestore.tar.gz" ]] && cs_args+=(filestore="$final_dir/filestore.tar.gz")
  [[ -f "$final_dir/filestore.tar.gz.enc" ]] && cs_args+=(filestore="$final_dir/filestore.tar.gz.enc")
  cs_args+=(manifest="$final_dir/manifest.json")
  soviez_backup_checksums_write "$final_dir/checksums.txt" "${cs_args[@]}"
  cp -a "$final_dir/checksums.txt" "$staging/checksums.txt"

  # Transfer must not hide destination failures behind pipe/tail success.
  local xfer_out xfer_rc=0
  set +e
  xfer_out="$(soviez_backup_transfer "$dest_json" "$final_dir" "$backup_id" "$tenant_id" 2>&1)"
  xfer_rc=$?
  set -e
  if [[ $xfer_rc -ne 0 ]]; then
    soviez_backup_state_write "$op_id" failed_retryable transfer_failed "{}"
    soviez_backup_die BACKUP_TRANSFER_FAILED "Transfer failed: $xfer_out"
  fi
  location=""
  set +e
  location="$(printf '%s\n' "$xfer_out" | grep -E '^sftp://|^s3://|^file://|^local:' | tail -n 1)"
  set -e
  if [[ -z "$location" ]]; then
    location="$(printf '%s\n' "$xfer_out" | grep -v '^{' | tail -n 1 | tr -d '\r')"
  fi
  location="$(printf '%s' "$location" | tr -d '\r' | awk 'NR==1{print; exit}')"

  # Also keep canonical local inventory copy under data dir
  local bdir
  bdir="$(soviez_backup_dir "$tenant_id" "$backup_id")"
  mkdir -p "$bdir"
  cp -a "$final_dir"/. "$bdir/"
  # Keep encrypted package as stored; do not mix plaintext companions into inventory dir.

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local size
  size="$(du -sk "$bdir" 2>/dev/null | awk '{print $1*1024}' || echo 0)"
  obj="$(SOVIEZ_O="$obj" SOVIEZ_LOC="$location" SOVIEZ_ENC="$enc_alg" \
    SOVIEZ_PAUSE="$pause_secs" SOVIEZ_NOW="$now" SOVIEZ_SZ="$size" \
    SOVIEZ_COMP="$components" python3 - <<'PY'
import json, os
o = json.loads(os.environ["SOVIEZ_O"])
o["location"] = os.environ["SOVIEZ_LOC"]
o["completed_at"] = os.environ["SOVIEZ_NOW"]
o["maintenance_pause_seconds"] = int(os.environ["SOVIEZ_PAUSE"])
o["stored_size_bytes"] = int(os.environ["SOVIEZ_SZ"])
o["components"] = json.loads(os.environ["SOVIEZ_COMP"])
o["encryption"] = {
  "enabled": os.environ["SOVIEZ_ENC"] != "none",
  "algorithm": os.environ["SOVIEZ_ENC"],
  "key_ref": "env:SOVIEZ_BACKUP_PASSPHRASE" if os.environ["SOVIEZ_ENC"] != "none" else "",
}
o["status"] = "completed"
o["restore_capable"] = o.get("backup_type") == "full"
print(json.dumps(o, separators=(",", ":")))
PY
)"
  soviez_backup_write_object "$tenant_id" "$backup_id" "$obj" >/dev/null
  soviez_backup_inventory_upsert "$obj"

  soviez_backup_state_write "$op_id" verifying verifying "{}"
  # Verify in subshell so a hard die cannot abort a completed package
  if ! ( soviez_backup_verify_level1 "$backup_id" >/dev/null ); then
    soviez_backup_state_write "$op_id" failed_retryable verify_failed \
      "{\"environment_id\":\"$tenant_id\",\"backup_id\":\"$backup_id\"}"
    soviez_backup_die BACKUP_VERIFY_FAILED "Backup package failed Level-1 verification"
  fi

  soviez_backup_state_write "$op_id" completed completed \
    "{\"environment_id\":\"$tenant_id\",\"backup_id\":\"$backup_id\"}"
  if declare -F soviez_ops_sync_terminal >/dev/null 2>&1; then
    soviez_ops_sync_terminal "$op_id" "$SOVIEZ_BACKUP_OP_TYPE" "$tenant_id" completed \
      "$(soviez_backup_op_state_file "$op_id")" 2>/dev/null || true
  fi

  # Schedule retention after success (dry-run classification recorded)
  if declare -F soviez_backup_retention_classify >/dev/null 2>&1; then
    soviez_backup_retention_classify "$tenant_id" > "$(soviez_backup_op_dir "$op_id")/retention_class.json" 2>/dev/null || true
  fi

  rm -rf "$staging"

  SOVIEZ_OP="$op_id" SOVIEZ_BID="$backup_id" SOVIEZ_T="$tenant_id" SOVIEZ_LOC="$location" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "BACKUP_COMPLETED",
  "operation_id": os.environ["SOVIEZ_OP"],
  "backup_id": os.environ["SOVIEZ_BID"],
  "production_id": os.environ["SOVIEZ_T"],
  "location": os.environ["SOVIEZ_LOC"],
}, separators=(",", ":")))
PY
}

soviez_backup_stage_live_backup() {
  # Shared Stage live backup: real pg_dump when PG available, else fixture path.
  # Args: stage_id
  local stage_id="$1"
  if declare -F soviez_stage_paths_init >/dev/null 2>&1; then
    soviez_stage_paths_init
  fi
  local ident
  ident="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage"
  local backup_root="${SOVIEZ_ROOT:-/var/soviez}/backups/stages"
  mkdir -p "$backup_root"
  local ts archive tmp
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  archive="$backup_root/${stage_id}-${ts}.tar"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/meta" "$tmp/filestore" "$tmp/db"
  printf '%s' "$ident" > "$tmp/meta/identity.json"

  local fs db_name
  fs="$(soviez_json_get "$ident" stage_filestore_path)"
  db_name="$(soviez_json_get "$ident" stage_db_name)"
  if [[ -d "$fs" ]]; then
    cp -a "$fs"/. "$tmp/filestore/" 2>/dev/null || true
  fi

  local dump="$tmp/db/db.dump"
  # MUST attempt live dump when PG available (closes Stage live-DB debt)
  if soviez_backup_pg_available || [[ "${SOVIEZ_STAGE_USE_LIVE_PG:-0}" == "1" ]]; then
    if declare -F soviez_backup_pg_dump_fc >/dev/null 2>&1; then
      soviez_backup_pg_dump_fc "$db_name" "$dump" || {
        rm -rf "$tmp"
        if declare -F soviez_stage_die >/dev/null 2>&1; then
          soviez_stage_die SNAPSHOT_FAILED "Live pg_dump failed for stage $stage_id"
        fi
        return 1
      }
    elif declare -F soviez_stage_pg_dump_fc >/dev/null 2>&1; then
      soviez_stage_pg_dump_fc "$db_name" "$dump" || {
        rm -rf "$tmp"
        soviez_stage_die SNAPSHOT_FAILED "Live pg_dump failed for stage $stage_id"
      }
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    if [[ -d "${SOVIEZ_ROOT}/stage-dbs/$db_name" ]]; then
      cp -a "$SOVIEZ_ROOT/stage-dbs/$db_name"/. "$tmp/db/"
    else
      printf 'PGDMP\x01FIXTURE stage=%s db=%s\n' "$stage_id" "$db_name" > "$dump"
    fi
  else
    # Attempt dump anyway if pg_dump exists
    if command -v pg_dump >/dev/null 2>&1 || [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]]; then
      soviez_backup_pg_dump_fc "$db_name" "$dump" || true
    fi
    if [[ ! -f "$dump" ]]; then
      printf 'PGDMP\x01INCOMPLETE stage=%s\n' "$stage_id" > "$dump"
    fi
  fi

  tar -C "$tmp" -cf "$archive" .
  local sum
  if declare -F soviez_sha256_file >/dev/null 2>&1; then
    sum="$(soviez_sha256_file "$archive")"
  else
    sum="$(soviez_backup_sha256_file "$archive")"
  fi
  printf '%s' "$sum" > "${archive}.sha256"
  rm -rf "$tmp"
  echo "Backup written: $archive"
  echo "SHA256: $sum"
}
