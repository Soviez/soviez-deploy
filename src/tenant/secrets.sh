# shellcheck shell=bash

soviez_tenant_secret_path() {
  local name="$1"
  printf '%s/%s\n' "$SOVIEZ_SECRETS_DIR" "$name"
}

soviez_tenant_secret_write() {
  local name="$1"
  local value="$2"
  local path
  path="$(soviez_tenant_secret_path "$name")"
  mkdir -p "$SOVIEZ_SECRETS_DIR"
  chmod 700 "$SOVIEZ_SECRETS_DIR"
  umask 077
  printf '%s' "$value" > "$path"
  chmod 600 "$path"
  # Phase 24: fingerprint sidecar for hygiene/audit (never log plaintext).
  if declare -F soviez_security_secret_fingerprint >/dev/null 2>&1; then
    printf '%s\n' "$(soviez_security_secret_fingerprint "$value")" > "${path}.sha256"
    chmod 600 "${path}.sha256"
  fi
  if declare -F soviez_security_assert_private_key_perms >/dev/null 2>&1; then
    case "$name" in
      *private*|*_key|*signing*) soviez_security_assert_private_key_perms "$path" || true ;;
    esac
  fi
}

soviez_tenant_secret_read() {
  local name="$1"
  local path
  path="$(soviez_tenant_secret_path "$name")"
  [[ -f "$path" ]] || return 1
  cat "$path"
}
