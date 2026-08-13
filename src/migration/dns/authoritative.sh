# shellcheck shell=bash

soviez_migration_dns_authoritative_lookup() {
  soviez_migration_dns_query "$1" "${2:-TXT}" authoritative
}

soviez_migration_dns_authoritative_match() {
  local name="$1" rtype="$2" expected="$3"
  local found ok=1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line="${line#\"}"; line="${line%\"}"
    if [[ "$line" == "$expected" ]]; then ok=0; break; fi
  done < <(soviez_migration_dns_authoritative_lookup "$name" "$rtype")
  return "$ok"
}
