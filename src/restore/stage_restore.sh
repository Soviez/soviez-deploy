# shellcheck shell=bash

soviez_restore_as_stage() {
  # Args: backup_id stage_domain confirm
  # Requires Stage entitlement (fixture: SOVIEZ_STAGE_ENTITLEMENT_OK=1)
  local backup_id="$1" stage_domain="${2:-}" confirm="${3:-0}"
  [[ -n "$backup_id" ]] || soviez_restore_die RESTORE_BACKUP_REQUIRED "backup_id required"

  if [[ "${SOVIEZ_STAGE_ENTITLEMENT_OK:-0}" != "1" ]]; then
    if declare -F soviez_stage_entitlement_check >/dev/null 2>&1; then
      soviez_stage_entitlement_check >/dev/null 2>&1 \
        || soviez_restore_die RESTORE_STAGE_ENTITLEMENT_REQUIRED "Stage entitlement required"
    else
      soviez_restore_die RESTORE_STAGE_ENTITLEMENT_REQUIRED "Stage entitlement required (SOVIEZ_STAGE_ENTITLEMENT_OK)"
    fi
  fi

  if [[ "$confirm" != "1" && "${SOVIEZ_RESTORE_ASSUME_YES:-0}" != "1" && ! -t 0 ]]; then
    soviez_restore_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Restore-as-Stage requires --confirm"
  fi

  local backup
  backup="$(soviez_restore_resolve_backup "$backup_id")" || exit $?
  local btype
  btype="$(soviez_json_get "$backup" backup_type)"
  if [[ "$btype" == "database_only" || "$btype" == "database-only" ]]; then
    soviez_restore_die RESTORE_DATABASE_ONLY_BACKUP_DENIED "database-only cannot seed Stage restore"
  fi

  # Fixture path: materialize under stages with rotated UUID marker
  if declare -F soviez_backup_paths_init >/dev/null 2>&1; then
    soviez_backup_paths_init
  fi
  if declare -F soviez_stage_paths_init >/dev/null 2>&1; then
    soviez_stage_paths_init
  fi

  local stage_id
  stage_id="rstg-$(printf '%s' "$backup_id" | tr -cd 'a-zA-Z0-9' | cut -c1-20)"
  local sdir
  if declare -F soviez_stage_dir >/dev/null 2>&1; then
    sdir="$(soviez_stage_dir "$stage_id")"
  else
    sdir="${SOVIEZ_STAGES_DIR:-${SOVIEZ_ROOT:-/var/soviez}/stages}/$stage_id"
  fi
  mkdir -p "$sdir/filestore" "$sdir/config" "$sdir/secrets"
  local prod_id bdir
  prod_id="$(soviez_json_get "$backup" production_id)"
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"

  if [[ -f "$bdir/db.dump" || -f "$bdir/db.dump.enc" ]]; then
    mkdir -p "$sdir/db"
    if [[ -f "$bdir/db.dump.enc" ]]; then
      soviez_backup_decrypt_file "$bdir/db.dump.enc" "$sdir/db/db.dump"
    else
      cp -a "$bdir/db.dump" "$sdir/db/db.dump"
    fi
  fi
  for cand in filestore.tar.zst filestore.tar.gz filestore.tar; do
    if [[ -f "$bdir/$cand" ]]; then
      soviez_backup_filestore_extract "$bdir/$cand" "$sdir/filestore"
      break
    fi
  done

  local new_uuid
  new_uuid="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || echo stage-uuid-fixture)"
  printf '%s' "$new_uuid" > "$sdir/config/stage_database_uuid.txt"
  printf 'stage_domain=%s\nsource_backup=%s\n' "${stage_domain:-pending}" "$backup_id" \
    > "$sdir/config/restore_as_stage.txt"

  SOVIEZ_S="$stage_id" SOVIEZ_B="$backup_id" SOVIEZ_U="$new_uuid" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "RESTORE_AS_STAGE_PREPARED",
  "stage_id": os.environ["SOVIEZ_S"],
  "backup_id": os.environ["SOVIEZ_B"],
  "stage_database_uuid": os.environ["SOVIEZ_U"],
}, separators=(",", ":")))
PY
}
