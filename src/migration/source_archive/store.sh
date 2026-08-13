# shellcheck shell=bash
# Optional remote copy of encrypted archive bundle (Phase 16 destination primitives).
# Interrupt / lost-ack hooks for Phase 22 G3 certification. Never deletes source data.

soviez_migration_p22_archive_remote_enabled() {
  [[ -n "${SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE:-}" || -n "${SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE:-}" ]]
}

soviez_migration_p22_archive_store_receipt_path() {
  printf '%s/remote_store.json\n' "$(soviez_migration_p22_archive_op_dir "$1")"
}

soviez_migration_p22_archive_store_ack_path() {
  printf '%s/remote_store.ack\n' "$(soviez_migration_p22_archive_op_dir "$1")"
}

# Exact-path upload of archive_bundle.tar.enc via Phase 16 S3/SFTP helpers.
soviez_migration_p22_archive_store_remote() {
  local op_id="$1"
  local op_dir enc staging receipt ackf kind profile_id profile prod_id backup_id out
  op_dir="$(soviez_migration_p22_archive_op_dir "$op_id")"
  enc="$op_dir/archive_bundle.tar.enc"
  receipt="$(soviez_migration_p22_archive_store_receipt_path "$op_id")"
  ackf="$(soviez_migration_p22_archive_store_ack_path "$op_id")"

  [[ -f "$enc" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "encrypted bundle missing for remote store"

  # Idempotent: already stored + acknowledged.
  if [[ -f "$receipt" && -f "$ackf" ]]; then
    if [[ "$(soviez_json_get "$(cat "$receipt")" status 2>/dev/null || true)" == "stored" ]]; then
      cat "$receipt"
      return 0
    fi
  fi

  # Lost-ack recovery: remote write completed, local ack missing → re-ack without re-upload if object present.
  if [[ -f "$receipt" ]] && [[ "$(soviez_json_get "$(cat "$receipt")" write_completed 2>/dev/null || true)" == "True" \
       || "$(soviez_json_get "$(cat "$receipt")" write_completed 2>/dev/null || true)" == "true" ]]; then
    if [[ ! -f "$ackf" ]]; then
      if [[ "${SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK:-0}" == "1" ]]; then
        # First pass after write: pretend ack lost (injection once).
        unset SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK
        export SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK=0
        soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED \
          "injected lost-ack after remote archive write"
      fi
      printf 'acked\n' > "$ackf"
      SOVIEZ_R="$receipt" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_R"]
d=json.load(open(p))
d["status"]="stored"
d["ack"]="idempotent_retry"
d["duplicate_upload"]=False
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(open(p).read())
PY
      return 0
    fi
  fi

  if ! soviez_migration_p22_archive_remote_enabled; then
    # Local-only archive is valid outside remote cert destinations.
    printf '{"status":"local_only","operation_id":"%s","purge_authorized":false}\n' "$op_id" > "$receipt"
    cat "$receipt"
    return 0
  fi

  if [[ "${SOVIEZ_MIG_P22_ARCHIVE_UPLOAD_INTERRUPT:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_ARCHIVE_UPLOAD_INTERRUPT
    export SOVIEZ_MIG_P22_ARCHIVE_UPLOAD_INTERRUPT=0
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "injected interrupt mid-upload once"
  fi

  staging="$op_dir/remote_staging"
  mkdir -p "$staging"
  # Exact filename required by cert tests.
  cp -f "$enc" "$staging/archive_bundle.tar.enc"
  prod_id="p22-archive"
  backup_id="$op_id"

  if [[ -n "${SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE:-}" ]]; then
    kind=s3
    profile_id="$SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE"
    if [[ "${SOVIEZ_MIG_P22_S3_INTERRUPT:-0}" == "1" ]] || [[ -n "${SOVIEZ_BACKUP_S3_INTERRUPT:-}" ]]; then
      # before_first_part works for small objects; middle_part needs multipart (>=2 parts).
      export SOVIEZ_BACKUP_S3_INTERRUPT="${SOVIEZ_BACKUP_S3_INTERRUPT:-before_first_part}"
    fi
    profile="$(soviez_backup_destination_resolve "$profile_id")"
    set +e
    out="$(soviez_backup_s3_dest_put "$profile" "$staging" "$backup_id" "$prod_id" 2>&1)"
    local rc=$?
    set -e
    unset SOVIEZ_BACKUP_S3_INTERRUPT 2>/dev/null || true
    unset SOVIEZ_MIG_P22_S3_INTERRUPT 2>/dev/null || true
    export SOVIEZ_MIG_P22_S3_INTERRUPT=0
    if [[ $rc -ne 0 ]]; then
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "S3 archive upload interrupted"
      fi
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "S3 archive upload failed: $out"
    fi
  elif [[ -n "${SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE:-}" ]]; then
    kind=sftp
    profile_id="$SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE"
    if [[ "${SOVIEZ_MIG_P22_SFTP_INTERRUPT:-0}" == "1" ]] || [[ -n "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" ]]; then
      export SOVIEZ_BACKUP_SFTP_INTERRUPT="${SOVIEZ_BACKUP_SFTP_INTERRUPT:-mid_upload}"
    fi
    profile="$(soviez_backup_destination_resolve "$profile_id")"
    set +e
    out="$(soviez_backup_sftp_dest_put "$profile" "$staging" "$backup_id" "$prod_id" 2>&1)"
    local rc=$?
    set -e
    unset SOVIEZ_BACKUP_SFTP_INTERRUPT 2>/dev/null || true
    unset SOVIEZ_MIG_P22_SFTP_INTERRUPT 2>/dev/null || true
    export SOVIEZ_MIG_P22_SFTP_INTERRUPT=0
    if [[ $rc -ne 0 ]]; then
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "SFTP archive upload interrupted"
      fi
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "SFTP archive upload failed: $out"
    fi
  else
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "remote store profile missing"
  fi

  # Mark write completed before local ack (lost-ack window).
  SOVIEZ_OUT="$receipt" SOVIEZ_OP="$op_id" SOVIEZ_KIND="$kind" SOVIEZ_PROF="$profile_id" \
  SOVIEZ_LOC="${out:-}" SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_archive_remote_store.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "kind": os.environ["SOVIEZ_KIND"],
  "profile_id": os.environ["SOVIEZ_PROF"],
  "object":"archive_bundle.tar.enc",
  "location": os.environ.get("SOVIEZ_LOC","").strip().splitlines()[-1] if os.environ.get("SOVIEZ_LOC") else "",
  "write_completed": True,
  "status": "write_completed",
  "purge_authorized": False,
  "deletion_performed": False,
  "duplicate_upload": False,
  "stored_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY

  if [[ "${SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK
    export SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK=0
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED \
      "injected lost-ack after remote archive write"
  fi

  printf 'acked\n' > "$ackf"
  SOVIEZ_R="$receipt" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_R"]
d=json.load(open(p))
d["status"]="stored"
d["ack"]="ok"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(open(p).read())
PY
}

# Retrieve remote copy (optional verify). Interrupt once then clear.
soviez_migration_p22_archive_retrieve_remote() {
  local op_id="$1"
  local dest="${2:-}"
  local op_dir enc receipt kind profile_id profile prod_id backup_id out
  op_dir="$(soviez_migration_p22_archive_op_dir "$op_id")"
  enc="$op_dir/archive_bundle.tar.enc"
  receipt="$(soviez_migration_p22_archive_store_receipt_path "$op_id")"
  dest="${dest:-$op_dir/remote_retrieve}"
  mkdir -p "$dest"

  if [[ "${SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT
    export SOVIEZ_MIG_P22_ARCHIVE_RETRIEVE_INTERRUPT=0
    soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "injected interrupt mid-retrieve once"
  fi

  [[ -f "$receipt" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "remote store receipt missing"
  kind="$(soviez_json_get "$(cat "$receipt")" kind)"
  profile_id="$(soviez_json_get "$(cat "$receipt")" profile_id)"
  prod_id="p22-archive"
  backup_id="$op_id"
  profile="$(soviez_backup_destination_resolve "$profile_id")"

  if [[ "$kind" == "s3" ]]; then
    set +e
    out="$(soviez_backup_s3_dest_get "$profile" "$dest" "$backup_id" "$prod_id" 2>&1)"
    local rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "S3 retrieve interrupted"
      fi
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "S3 retrieve failed"
    fi
  elif [[ "$kind" == "sftp" ]]; then
    set +e
    out="$(soviez_backup_sftp_dest_get "$profile" "$dest" "$backup_id" "$prod_id" 2>&1)"
    local rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_migration_die MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED "SFTP retrieve interrupted"
      fi
      soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "SFTP retrieve failed"
    fi
  else
    # local_only — copy local enc
    cp -f "$enc" "$dest/archive_bundle.tar.enc"
  fi
  printf '{"status":"retrieved","operation_id":"%s","dest":"%s"}\n' "$op_id" "$dest"
}
