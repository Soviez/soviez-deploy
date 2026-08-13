# shellcheck shell=bash
# Phase 21 DNS propagation observation — authoritative fixture zone plus two
# "public" resolver views. When SOVIEZ_MIG_P21_PUBLIC_RESOLVER_A/B are set
# they are used as independent snapshot files (integration mode); otherwise
# the same authoritative fixture zone is read for all views.

soviez_migration_p21_propagation_view() {
  local view="$1" fqdn="$2" rtype="${3:-A}"
  case "$view" in
    authoritative)
      soviez_migration_p21_dns_snapshot "$fqdn" "$rtype"
      ;;
    public_a)
      if [[ -n "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_A:-}" && -f "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_A}/$fqdn/$rtype.txt" ]]; then
        cat "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_A}/$fqdn/$rtype.txt"
      else
        soviez_migration_p21_dns_snapshot "$fqdn" "$rtype"
      fi
      ;;
    public_b)
      if [[ -n "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_B:-}" && -f "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_B}/$fqdn/$rtype.txt" ]]; then
        cat "${SOVIEZ_MIG_P21_PUBLIC_RESOLVER_B}/$fqdn/$rtype.txt"
      else
        soviez_migration_p21_dns_snapshot "$fqdn" "$rtype"
      fi
      ;;
  esac
}

soviez_migration_p21_propagation_observe() {
  local fqdn="${1:-}" expected="${2:-}"
  [[ -n "$fqdn" && -n "$expected" ]] || soviez_migration_die MIGRATION_DNS_RECORD_NOT_FOUND "fqdn/expected required"
  local auth pub_a pub_b matches=0
  auth="$(soviez_migration_p21_propagation_view authoritative "$fqdn")"
  pub_a="$(soviez_migration_p21_propagation_view public_a "$fqdn")"
  pub_b="$(soviez_migration_p21_propagation_view public_b "$fqdn")"
  [[ "$auth" == "$expected" ]] && matches=$((matches + 1))
  [[ "$pub_a" == "$expected" ]] && matches=$((matches + 1))
  [[ "$pub_b" == "$expected" ]] && matches=$((matches + 1))
  local majority=false
  [[ "$matches" -ge 3 ]] && majority=true
  printf '{"fqdn":"%s","expected":"%s","authoritative":"%s","public_a":"%s","public_b":"%s","matches":%s,"majority":%s}\n' \
    "$fqdn" "$expected" "$auth" "$pub_a" "$pub_b" "$matches" "$majority"
}
