# shellcheck shell=bash

soviez_migration_domain_refuse_wildcard_fqdn() {
  local fqdn="$1"
  [[ -z "$fqdn" ]] && return 0
  [[ "$fqdn" == *"*"* || "$fqdn" == *"?"* ]] && return 0
  [[ "$fqdn" == "*."* ]] && return 0
  return 1
}

soviez_migration_load_pair() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  local path
  path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown pair: $pair_id"
  local pair
  pair="$(cat "$path")"
  [[ "$(soviez_json_get "$pair" aborted)" != "true" ]] || soviez_migration_die MIGRATION_ABORTED "Pair aborted"
  if soviez_migration_is_expired "$(soviez_json_get "$pair" pair_expires_at)"; then
    soviez_migration_die MIGRATION_PAIR_EXPIRED "Pair expired"
  fi
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Pair signature invalid"
  fi
  printf '%s' "$pair"
}

soviez_migration_domain_production_fqdn() {
  local pair_json="$1"
  local discovery_id discovery
  discovery_id="$(soviez_json_get "$pair_json" source_discovery_id)"
  discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json" 2>/dev/null || echo '{}')"
  SOVIEZ_D="$discovery" python3 - <<'PY'
import json, os
d=json.loads(os.environ["SOVIEZ_D"])
dom=(d.get("runtime") or {}).get("domain") or (d.get("identity") or {}).get("domain") or ""
print(dom)
PY
}

soviez_migration_domain_assert_migration_fqdn() {
  local migration_fqdn="$1" production_fqdn="$2"
  [[ -n "$migration_fqdn" ]] || soviez_migration_die MIGRATION_DOMAIN_REQUIRED "Migration FQDN required"
  if soviez_migration_domain_refuse_wildcard_fqdn "$migration_fqdn"; then
    soviez_migration_die MIGRATION_DOMAIN_INVALID "Wildcard migration FQDN refused"
  fi
  if [[ -n "$production_fqdn" && "$migration_fqdn" == "$production_fqdn" ]]; then
    soviez_migration_die MIGRATION_DOMAIN_INVALID "Production domain cannot be migration domain"
  fi
}

soviez_migration_domain_assert_pair_id() {
  local pair_id="$1" expected_pair_id="$2"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  [[ "$pair_id" == "$expected_pair_id" ]] || soviez_migration_die MIGRATION_PAIR_IDENTITY_MISMATCH "pair-id mismatch"
}
