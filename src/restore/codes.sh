# shellcheck shell=bash

SOVIEZ_ERR_RESTORE=25
SOVIEZ_RESTORE_OP_TYPE=production_restore
SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS="${SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS:-24}"

SOVIEZ_RESTORE_CODES=(
  RESTORE_TARGET_REQUIRED
  RESTORE_TARGET_INVALID
  RESTORE_BACKUP_REQUIRED
  RESTORE_BACKUP_NOT_FOUND
  RESTORE_BACKUP_OWNERSHIP_MISMATCH
  RESTORE_WRONG_PRODUCTION
  RESTORE_BACKUP_NOT_VERIFIED
  RESTORE_DATABASE_ONLY_BACKUP_DENIED
  RESTORE_MANIFEST_INVALID
  RESTORE_SIGNATURE_INVALID
  RESTORE_CHECKSUM_MISMATCH
  RESTORE_ENCRYPTION_KEY_REQUIRED
  RESTORE_ENCRYPTION_KEY_INVALID
  RESTORE_IMAGE_UNAVAILABLE
  RESTORE_ERP_VERSION_INCOMPATIBLE
  RESTORE_POSTGRES_INCOMPATIBLE
  RESTORE_ADDON_MISSING
  RESTORE_LICENSE_BINDING_MISMATCH
  RESTORE_CAPACITY_INSUFFICIENT
  RESTORE_CONFLICT
  RESTORE_CANDIDATE_FAILED
  RESTORE_VALIDATION_FAILED
  RESTORE_SWITCH_FAILED
  RESTORE_POST_SWITCH_VALIDATION_FAILED
  RESTORE_ROLLBACK_REQUIRED
  RESTORE_ROLLBACK_FAILED
  RESTORE_RECOVERY_REQUIRED
  RESTORE_HOST_IDENTITY_MISMATCH
  RESTORE_STAGE_ENTITLEMENT_REQUIRED
  DESTRUCTIVE_CONFIRMATION_REQUIRED
)

soviez_restore_die() {
  local code="${1:-RESTORE_RECOVERY_REQUIRED}" message="${2:-Restore failed}"
  if declare -F soviez_log_error >/dev/null 2>&1; then
    soviez_log_error "${code}: ${message}"
  fi
  local redacted="$message"
  if declare -F soviez_redact_text >/dev/null 2>&1; then
    redacted="$(soviez_redact_text "$message")"
  fi
  SOVIEZ_RS_CODE="$code" SOVIEZ_RS_MSG="$redacted" python3 - <<'PY' >&2
import json, os
print(json.dumps({"ok": False, "code": os.environ["SOVIEZ_RS_CODE"],
                  "message": os.environ["SOVIEZ_RS_MSG"]}, separators=(",", ":")))
PY
  exit "$SOVIEZ_ERR_RESTORE"
}

soviez_restore_ok() {
  local code="${1:-OK}" message="${2:-OK}"
  local redacted="$message"
  if declare -F soviez_redact_text >/dev/null 2>&1; then
    redacted="$(soviez_redact_text "$message")"
  fi
  SOVIEZ_RS_CODE="$code" SOVIEZ_RS_MSG="$redacted" python3 - <<'PY'
import json, os
print(json.dumps({"ok": True, "code": os.environ["SOVIEZ_RS_CODE"],
                  "message": os.environ["SOVIEZ_RS_MSG"]}, separators=(",", ":")))
PY
}

soviez_restore_new_op_id() {
  local hex
  if declare -F soviez_rand_hex >/dev/null 2>&1; then
    hex="$(soviez_rand_hex 4)"
  else
    hex="$(openssl rand -hex 4 2>/dev/null || echo abcd)"
  fi
  printf 'rst-%s-%s\n' "$(date +%Y%m%d%H%M%S 2>/dev/null || echo 0)" "$hex"
}

soviez_restore_paths_init() {
  if declare -F soviez_backup_paths_init >/dev/null 2>&1; then
    soviez_backup_paths_init
  fi
  SOVIEZ_RESTORE_OPS_DIR="${SOVIEZ_RESTORE_OPS_DIR:-${SOVIEZ_BACKUP_ROOT:-${SOVIEZ_ROOT:-/var/soviez}/backups}/restore-operations}"
  SOVIEZ_RESTORE_CANDIDATES_DIR="${SOVIEZ_RESTORE_CANDIDATES_DIR:-${SOVIEZ_BACKUP_CANDIDATES_DIR:-${SOVIEZ_ROOT:-/var/soviez}/backups/candidates}}"
  export SOVIEZ_RESTORE_OPS_DIR SOVIEZ_RESTORE_CANDIDATES_DIR
  mkdir -p "$SOVIEZ_RESTORE_OPS_DIR" "$SOVIEZ_RESTORE_CANDIDATES_DIR"
  chmod 700 "$SOVIEZ_RESTORE_OPS_DIR" "$SOVIEZ_RESTORE_CANDIDATES_DIR"
}

soviez_restore_op_dir() { printf '%s/%s\n' "$SOVIEZ_RESTORE_OPS_DIR" "$1"; }
soviez_restore_op_state_file() { printf '%s/state.json\n' "$(soviez_restore_op_dir "$1")"; }
soviez_restore_candidate_dir() { printf '%s/%s\n' "$SOVIEZ_RESTORE_CANDIDATES_DIR" "$1"; }
soviez_restore_preserve_dir() { printf '%s/%s/preserve\n' "$(soviez_restore_op_dir "$1")" ; }
