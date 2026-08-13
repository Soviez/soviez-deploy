# shellcheck shell=bash

soviez_migration_dns_provider_create_record() {
  local name="$1" rtype="$2" value="$3" ttl="${4:-300}"
  local zone_dir view="${5:-authoritative}"
  zone_dir="$(soviez_migration_dns_fixture_zone_dir)"
  for view in authoritative public_a public_b; do
    mkdir -p "$zone_dir/$view/$name"
    printf '%s\n' "$value" > "$zone_dir/$view/$name/${rtype}.txt"
  done
  chmod -R u+rwX "$zone_dir" 2>/dev/null || true
  printf '{"created":true,"name":"%s","type":"%s","ttl":%s,"provider":"mock_fixture"}\n' "$name" "$rtype" "$ttl"
}

soviez_migration_dns_provider_delete_record() {
  local name="$1" rtype="$2"
  local zone_dir view
  zone_dir="$(soviez_migration_dns_fixture_zone_dir)"
  for view in authoritative public_a public_b; do
    rm -f "$zone_dir/$view/$name/${rtype}.txt" 2>/dev/null || true
  done
}
