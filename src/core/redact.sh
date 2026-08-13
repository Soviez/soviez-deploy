# shellcheck shell=bash

# Patterns for values that must never appear in logs, JSON, or evidence.
# Use '#' as sed delimiter so URLs with '/' do not break substitution.
SOVIEZ_REDACT_PATTERNS=(
  'x-soviez-credential:[[:space:]]*[^[:space:]"]+'
  '"credential"[[:space:]]*:[[:space:]]*"[^"]*"'
  'credential=[^[:space:]"]+'
  'activation[_-]?key[[:space:]*:=]+[^[:space:]"]+'
  'license[_-]?key[[:space:]*:=]+[^[:space:]"]+'
  'SOV-[A-Z0-9-]{8,}'
  'password[[:space:]*:=]+[^[:space:]"]+'
  'token[[:space:]*:=]+[^[:space:]"]+'
  'Bearer[[:space:]]+[^[:space:]"]+'
  'Authorization:[[:space:]]*[^[:space:]"]+'
  'postgres(ql)?://[^[:space:]"]+'
  'mysql://[^[:space:]"]+'
  '-----BEGIN[^-]*PRIVATE KEY-----'
  'device-private-key'
)

soviez_redact_text() {
  local text="${1:-}"
  local pat
  for pat in "${SOVIEZ_REDACT_PATTERNS[@]}"; do
    text="$(printf '%s' "$text" | sed -E "s#${pat}#[REDACTED]#gi")"
  done
  printf '%s' "$text"
}

soviez_redact_args_for_log() {
  local out=()
  local arg
  for arg in "$@"; do
    out+=("$(soviez_redact_text "$arg")")
  done
  printf '%s\n' "${out[@]}"
}

soviez_secret_env_names() {
  printf '%s\n' \
    SOVIEZ_DEVICE_CREDENTIAL \
    SOVIEZ_ACTIVATION_KEY \
    SOVIEZ_LICENSE_KEY \
    SOVIEZ_REGISTRY_PASSWORD \
    SOVIEZ_DB_PASSWORD
}

soviez_assert_no_secret_in_text() {
  local text="$1"
  local label="${2:-output}"
  local name val
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    val="${!name:-}"
    [[ -z "$val" ]] && continue
    if printf '%s' "$text" | grep -Fq "$val"; then
      return 1
    fi
  done < <(soviez_secret_env_names)
  return 0
}
