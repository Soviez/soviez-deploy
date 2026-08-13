# shellcheck shell=bash
# Phase 24 — secret hygiene inventory helpers.

soviez_security_secret_class_label() {
  local path_or_name="$1"
  case "$path_or_name" in
    *service_role*|*SERVICE_ROLE*) echo privileged_backend ;;
    *private*|*_key.pem|*signing*) echo private_key ;;
    *registry*|*docker*auth*) echo registry_credential ;;
    *password*|*passwd*) echo password ;;
    *) echo secret ;;
  esac
}

soviez_security_assert_no_service_role_in_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if grep -Ei 'service_role[_-]?(key|secret|jwt)[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$file" >/dev/null 2>&1; then
    soviez_security_die SECURITY_SERVICE_ROLE_EXPOSED "service-role credential shape in $(basename "$file")"
  fi
  if grep -Ei 'SUPABASE_SERVICE_ROLE(_KEY)?[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' "$file" >/dev/null 2>&1; then
    soviez_security_die SECURITY_SERVICE_ROLE_EXPOSED "supabase service-role credential shape in $(basename "$file")"
  fi
  return 0
}
