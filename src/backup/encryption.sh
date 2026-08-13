# shellcheck shell=bash

soviez_backup_encryption_required() {
  # Args: destination_kind (local|s3|sftp|remote)
  local kind="${1:-local}"
  case "$kind" in
    s3|sftp|remote)
      return 0
      ;;
    local)
      if [[ "${SOVIEZ_BACKUP_DISABLE_ENCRYPTION:-0}" == "1" ]]; then
        if declare -F soviez_log_warn >/dev/null 2>&1; then
          soviez_log_warn "ADVANCED: local backup encryption disabled (SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1)"
        else
          echo "ADVANCED: local backup encryption disabled" >&2
        fi
        return 1
      fi
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

soviez_backup_encryption_passphrase_ready() {
  [[ -n "${SOVIEZ_BACKUP_PASSPHRASE:-}" ]] && return 0
  [[ -n "${SOVIEZ_BACKUP_PASSPHRASE_FILE:-}" && -f "${SOVIEZ_BACKUP_PASSPHRASE_FILE}" ]] && return 0
  return 1
}

soviez_backup_encryption_load_passphrase() {
  # Sets SOVIEZ_BACKUP_PASSPHRASE from file if needed; never prints it.
  if [[ -z "${SOVIEZ_BACKUP_PASSPHRASE:-}" && -n "${SOVIEZ_BACKUP_PASSPHRASE_FILE:-}" && -f "${SOVIEZ_BACKUP_PASSPHRASE_FILE}" ]]; then
    # shellcheck disable=SC2034
    SOVIEZ_BACKUP_PASSPHRASE="$(cat "$SOVIEZ_BACKUP_PASSPHRASE_FILE")"
    export SOVIEZ_BACKUP_PASSPHRASE
  fi
  [[ -n "${SOVIEZ_BACKUP_PASSPHRASE:-}" ]] || return 1
  return 0
}

soviez_backup_encrypt_file() {
  # Args: input output
  # Uses openssl enc -aes-256-cbc -pbkdf2 -iter 100000 with passphrase from env.
  local inp="$1" out="$2"
  [[ -f "$inp" ]] || soviez_backup_die BACKUP_ENCRYPTION_FAILED "Missing input for encryption"
  if ! soviez_backup_encryption_load_passphrase; then
    soviez_backup_die BACKUP_ENCRYPTION_KEY_REQUIRED "SOVIEZ_BACKUP_PASSPHRASE required"
  fi
  mkdir -p "$(dirname "$out")"
  # Passphrase via env FD-friendly: openssl -pass env:VAR (not argv)
  openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
    -in "$inp" -out "$out" \
    -pass env:SOVIEZ_BACKUP_PASSPHRASE \
    || soviez_backup_die BACKUP_ENCRYPTION_FAILED "openssl encrypt failed"
  chmod 600 "$out"
}

soviez_backup_decrypt_file() {
  # Args: input output
  local inp="$1" out="$2"
  [[ -f "$inp" ]] || soviez_backup_die BACKUP_ENCRYPTION_FAILED "Missing ciphertext"
  if ! soviez_backup_encryption_load_passphrase; then
    soviez_backup_die BACKUP_ENCRYPTION_KEY_REQUIRED "SOVIEZ_BACKUP_PASSPHRASE required"
  fi
  mkdir -p "$(dirname "$out")"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -in "$inp" -out "$out" \
    -pass env:SOVIEZ_BACKUP_PASSPHRASE \
    || soviez_backup_die BACKUP_ENCRYPTION_KEY_INVALID "openssl decrypt failed"
  chmod 600 "$out"
}

soviez_backup_maybe_encrypt() {
  # Args: input output destination_kind
  local inp="$1" out="$2" kind="${3:-local}"
  if soviez_backup_encryption_required "$kind"; then
    soviez_backup_encrypt_file "$inp" "$out"
    printf 'aes-256-cbc-pbkdf2\n'
  else
    cp -a "$inp" "$out"
    printf 'none\n'
  fi
}
