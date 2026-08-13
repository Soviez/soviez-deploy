# shellcheck shell=bash
# Phase 18 migration TLS policy — wraps ssl/policy.sh with migration-specific denies.

soviez_migration_tls_policy_assert() {
  local fqdn="$1" production_fqdn="$2" cert_mode="${3:-public}"
  soviez_migration_domain_assert_migration_fqdn "$fqdn" "$production_fqdn"
  if [[ "$cert_mode" == "self_signed" ]]; then
    soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "Self-signed final certificate denied"
  fi
  if declare -F soviez_ssl_policy_assert_ca >/dev/null 2>&1; then
    soviez_ssl_policy_assert_ca "$cert_mode"
  fi
}

soviez_migration_tls_policy_assert_production_preissue() {
  soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "Production domain TLS pre-issue denied in Phase 18"
}
