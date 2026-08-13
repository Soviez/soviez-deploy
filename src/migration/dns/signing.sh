# shellcheck shell=bash

soviez_migration_dns_challenge_binding_payload() {
  local pair_id="$1" prod_id="$2" prod_domain="$3" migration_fqdn="$4" \
    bootstrap_id="$5" dst_fp="$6" license_id="$7" op_id="$8" nonce="$9" expires="$10"
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s' \
    "$pair_id" "$prod_id" "$prod_domain" "$migration_fqdn" \
    "$bootstrap_id" "$dst_fp" "$license_id" "$op_id" "$nonce" "$expires"
}

soviez_migration_dns_challenge_sign() {
  local payload="$1"
  soviez_migration_sign_json "$payload"
}

soviez_migration_dns_challenge_verify_sig() {
  local payload="$1" sig="$2"
  local actual
  actual="$(soviez_migration_dns_challenge_sign "$payload")"
  [[ "$actual" == "$sig" ]]
}

soviez_migration_dns_challenge_txt_name() {
  local migration_fqdn="$1"
  printf '_soviez-migration.%s\n' "$migration_fqdn"
}

soviez_migration_dns_challenge_txt_value() {
  local challenge_id="$1" sig="$2"
  printf 'v1.%s.%s\n' "$challenge_id" "$sig"
}
