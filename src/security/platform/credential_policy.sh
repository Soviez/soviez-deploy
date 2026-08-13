# shellcheck shell=bash
# Security Gate S1 — weak / low-entropy credential policy (never log passwords).

soviez_sec_password_is_weak() {
  local password="$1"
  local lower
  lower="$(printf '%s' "$password" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    admin|admin123|password|odoo|root|123456|12345678|qwerty|changeme)
      return 0
      ;;
  esac
  return 1
}

soviez_sec_password_assert_not_weak() {
  local password="$1" context="${2:-credential}"
  if soviez_sec_password_is_weak "$password"; then
    if declare -F soviez_security_die >/dev/null 2>&1; then
      soviez_security_die SEC_CRIT_WEAK_ADMIN_CREDENTIAL "weak default credential refused (${context})"
    fi
    echo "[error] security:SEC_CRIT_WEAK_ADMIN_CREDENTIAL: weak default credential refused (${context})" >&2
    return 1
  fi
  return 0
}

soviez_sec_password_assert_min_entropy() {
  local password="$1" minlen="${2:-16}"
  local len="${#password}"
  if [[ "$len" -lt "$minlen" ]]; then
    if declare -F soviez_security_die >/dev/null 2>&1; then
      soviez_security_die SEC_CRIT_WEAK_ADMIN_CREDENTIAL "password shorter than ${minlen} (${#password} chars)"
    fi
    echo "[error] security:SEC_CRIT_WEAK_ADMIN_CREDENTIAL: password shorter than ${minlen}" >&2
    return 1
  fi
  if soviez_sec_password_is_weak "$password"; then
    soviez_sec_password_assert_not_weak "$password" "min_entropy"
    return 1
  fi
  return 0
}
