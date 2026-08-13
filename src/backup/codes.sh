# shellcheck shell=bash

SOVIEZ_ERR_BACKUP=24
SOVIEZ_BACKUP_OP_TYPE=production_backup
SOVIEZ_BACKUP_VERIFY_OP_TYPE=backup_verification
SOVIEZ_BACKUP_RESTORE_TEST_OP_TYPE=backup_restore_test
SOVIEZ_BACKUP_RETENTION_OP_TYPE=backup_retention_cleanup
SOVIEZ_BACKUP_EXPORT_OP_TYPE=backup_export
SOVIEZ_BACKUP_IMPORT_OP_TYPE=backup_import

SOVIEZ_BACKUP_CODES=(
  BACKUP_TARGET_REQUIRED
  BACKUP_TARGET_INVALID
  BACKUP_TARGET_AMBIGUOUS
  BACKUP_STAGE_TARGET_DENIED
  BACKUP_PRODUCTION_IDENTITY_MISMATCH
  BACKUP_HOST_IDENTITY_MISMATCH
  BACKUP_DESTINATION_REQUIRED
  BACKUP_DESTINATION_INVALID
  BACKUP_DESTINATION_UNREACHABLE
  BACKUP_DESTINATION_DENIED
  BACKUP_CAPACITY_INSUFFICIENT
  BACKUP_DISK_INSUFFICIENT
  BACKUP_INODES_INSUFFICIENT
  BACKUP_QUIESCE_FAILED
  BACKUP_RESUME_FAILED
  BACKUP_DATABASE_FAILED
  BACKUP_FILESTORE_FAILED
  BACKUP_MANIFEST_FAILED
  BACKUP_CHECKSUM_MISMATCH
  BACKUP_SIGNATURE_INVALID
  BACKUP_ENCRYPTION_REQUIRED
  BACKUP_ENCRYPTION_FAILED
  BACKUP_ENCRYPTION_KEY_REQUIRED
  BACKUP_ENCRYPTION_KEY_INVALID
  BACKUP_TRANSFER_FAILED
  BACKUP_TRANSFER_INTERRUPTED
  BACKUP_VERIFY_FAILED
  BACKUP_NOT_FOUND
  BACKUP_TYPE_INVALID
  BACKUP_ADVANCED_REQUIRED
  BACKUP_CONFLICT
  BACKUP_PIN_PROTECTED
  BACKUP_RETENTION_DENIED
  BACKUP_IMPORT_INVALID
  BACKUP_EXPORT_FAILED
  BACKUP_SCHEDULE_INVALID
  BACKUP_RECOVERY_REQUIRED
  BACKUP_PATH_DENIED
  BACKUP_RESTORE_TEST_FAILED
  BACKUP_MANIFEST_INVALID
  BACKUP_FILESTORE_INVALID
  DESTRUCTIVE_CONFIRMATION_REQUIRED
)

soviez_backup_die() {
  local code="${1:-BACKUP_RECOVERY_REQUIRED}" message="${2:-Backup failed}"
  if declare -F soviez_log_error >/dev/null 2>&1; then
    soviez_log_error "${code}: ${message}"
  fi
  local redacted="$message"
  if declare -F soviez_redact_text >/dev/null 2>&1; then
    redacted="$(soviez_redact_text "$message")"
  fi
  SOVIEZ_BK_CODE="$code" SOVIEZ_BK_MSG="$redacted" python3 - <<'PY' >&2
import json, os
print(json.dumps({"ok": False, "code": os.environ["SOVIEZ_BK_CODE"],
                  "message": os.environ["SOVIEZ_BK_MSG"]}, separators=(",", ":")))
PY
  exit "$SOVIEZ_ERR_BACKUP"
}

soviez_backup_ok() {
  local code="${1:-OK}" message="${2:-OK}"
  local redacted="$message"
  if declare -F soviez_redact_text >/dev/null 2>&1; then
    redacted="$(soviez_redact_text "$message")"
  fi
  SOVIEZ_BK_CODE="$code" SOVIEZ_BK_MSG="$redacted" python3 - <<'PY'
import json, os
print(json.dumps({"ok": True, "code": os.environ["SOVIEZ_BK_CODE"],
                  "message": os.environ["SOVIEZ_BK_MSG"]}, separators=(",", ":")))
PY
}
