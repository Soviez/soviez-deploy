# shellcheck shell=bash

soviez_migration_dns_public_resolver_views() {
  printf '%s\n' "public_a" "public_b"
}

soviez_migration_dns_public_resolvers_agree() {
  local name="$1" rtype="$2" expected="$3"
  local view lines match=0
  for view in $(soviez_migration_dns_public_resolver_views); do
    lines="$(soviez_migration_dns_query "$name" "$rtype" "$view" | tr '\n' '|')"
    if [[ "$lines" == *"$expected"* ]]; then
      match=$((match + 1))
    fi
  done
  [[ "$match" -ge 2 ]]
}

soviez_migration_dns_public_vs_authoritative() {
  local name="$1" rtype="$2"
  local auth pub_a pub_b
  auth="$(soviez_migration_dns_authoritative_lookup "$name" "$rtype" | head -1 | tr -d '"')"
  pub_a="$(soviez_migration_dns_query "$name" "$rtype" public_a | head -1 | tr -d '"')"
  pub_b="$(soviez_migration_dns_query "$name" "$rtype" public_b | head -1 | tr -d '"')"
  [[ -n "$auth" && "$auth" == "$pub_a" && "$auth" == "$pub_b" ]]
}
