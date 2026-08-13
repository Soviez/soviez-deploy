# shellcheck shell=bash

soviez_migration_write_json() {
  local path="$1" json="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$json" > "$path"
  chmod 600 "$path" 2>/dev/null || true
}

soviez_migration_read_json() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  cat "$path"
}

soviez_migration_outcome_banner() {
  local discovery="${1:-INCOMPLETE}" bootstrap="${2:-INCOMPLETE}" pair="${3:-UNTRUSTED}" \
        readiness="${4:-UNKNOWN}" routing="${5:-}"
  cat <<EOF
SOURCE DISCOVERY — ${discovery}
DESTINATION BOOTSTRAP — ${bootstrap}
MIGRATION PAIR — ${pair}
READINESS — ${readiness}
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
DESTINATION PRODUCTION NOT ACTIVATED
EOF
  if [[ -n "$routing" ]]; then
    cat <<EOF
ROUTING READINESS — ${routing}
NO PRODUCTION CUTOVER
SOURCE DNS UNCHANGED BY SOVIEZ
EOF
  fi
}

soviez_migration_phase18_banner() {
  local routing="${1:-UNKNOWN}"
  soviez_migration_outcome_banner "COMPLETE" "COMPLETE" "TRUSTED" "PASS" "$routing" >&2 || true
}
