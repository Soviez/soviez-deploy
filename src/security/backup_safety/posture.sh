# shellcheck shell=bash
# Security Gate S5 — backup destination posture classification.

soviez_s5_backup_classify_destination() {
  local dest="${1:-${SOVIEZ_BACKUP_DEST:-${SOVIEZ_S5_BACKUP_DEST:-}}}"
  dest="$(printf '%s' "$dest" | tr '[:upper:]' '[:lower:]')"
  case "$dest" in
    s3|s3://*|s3compat://*|minio://*|https://*s3*|*s3.amazonaws.com*|*r2.cloudflarestorage.com*|off_host_s3*)
      echo OFF_HOST_S3_COMPATIBLE
      ;;
    sftp|sftp://*|scp://*|ssh://*|off_host_sftp*)
      echo OFF_HOST_SFTP
      ;;
    local|local://*|file://*|/*|"")
      echo LOCAL_ONLY
      ;;
    *)
      # Explicit override.
      if [[ "${SOVIEZ_S5_BACKUP_CLASS:-}" =~ ^(LOCAL_ONLY|OFF_HOST_S3_COMPATIBLE|OFF_HOST_SFTP)$ ]]; then
        printf '%s\n' "$SOVIEZ_S5_BACKUP_CLASS"
      else
        echo LOCAL_ONLY
      fi
      ;;
  esac
}

soviez_s5_backup_dr_capable() {
  local class="${1:-}"
  if [[ -z "$class" ]]; then
    class="$(soviez_s5_backup_classify_destination)"
  fi
  case "$class" in
    LOCAL_ONLY)
      echo false
      return 1
      ;;
    OFF_HOST_S3_COMPATIBLE|OFF_HOST_SFTP)
      echo true
      return 0
      ;;
    *)
      echo false
      return 1
      ;;
  esac
}
