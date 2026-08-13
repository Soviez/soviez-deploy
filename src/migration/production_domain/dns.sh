# shellcheck shell=bash
# Phase 21 production DNS cutover — exact-record mutation only, no zone-wide
# or wildcard changes. Fixture zone is a plain directory tree that a real
# authoritative test DNS server can also be pointed at.

soviez_migration_p21_dns_zone_dir() {
  printf '%s\n' "${SOVIEZ_MIG_P21_DNS_ZONE_DIR:-$SOVIEZ_MIG_ROOT/dns_zone}"
}

soviez_migration_p21_dns_record_file() {
  local fqdn="$1" rtype="${2:-A}"
  printf '%s/%s/%s.txt\n' "$(soviez_migration_p21_dns_zone_dir)" "$fqdn" "$rtype"
}

soviez_migration_p21_dns_snapshot() {
  local fqdn="$1" rtype="${2:-A}"
  local f
  f="$(soviez_migration_p21_dns_record_file "$fqdn" "$rtype")"
  if [[ -f "$f" ]]; then cat "$f"; else printf 'unset\n'; fi
}

# soviez_migration_p21_dns_mutate <fqdn> <target> [rtype]
# Exact single-record mutation — never a zone apex wildcard or broad update.
soviez_migration_p21_dns_mutate() {
  local fqdn="${1:-}" target="${2:-}" rtype="${3:-A}"
  [[ -n "$fqdn" && -n "$target" ]] || soviez_migration_die MIGRATION_DOMAIN_REQUIRED "fqdn and target required"
  if [[ "$fqdn" == "*"* ]]; then
    soviez_migration_die MIGRATION_WILDCARD_ROUTE_FORBIDDEN "wildcard DNS record forbidden"
  fi
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_DNS_CUTOVER"
  local f
  f="$(soviez_migration_p21_dns_record_file "$fqdn" "$rtype")"
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$target" > "$f"
  printf '{"fqdn":"%s","type":"%s","value":"%s","mutated":true}\n' "$fqdn" "$rtype" "$target"
}

soviez_migration_p21_dns_manual_instructions() {
  local fqdn="${1:-}" target="${2:-}"
  SOVIEZ_F="$fqdn" SOVIEZ_T="$target" python3 - <<'PY'
import json, os
print(json.dumps({
  "fqdn": os.environ["SOVIEZ_F"],
  "instructions": [
    {"step": 1, "action": "Point exact A record to destination", "name": os.environ["SOVIEZ_F"], "value": os.environ["SOVIEZ_T"]},
    {"step": 2, "action": "Wait for authoritative + public resolver propagation"},
    {"step": 3, "action": "Confirm change with --migration-cutover-dns-try-again"},
  ],
  "do_not": ["Do not create a wildcard record", "Do not repoint unrelated apex records"],
}, indent=2))
PY
}

soviez_migration_p21_dns_rollback() {
  local fqdn="${1:-}" previous_target="${2:-}" rtype="${3:-A}"
  [[ -n "$previous_target" ]] || { printf '{"fqdn":"%s","rollback":"skipped","reason":"no_previous_target"}\n' "$fqdn"; return 0; }
  soviez_migration_p21_dns_mutate "$fqdn" "$previous_target" "$rtype"
}
