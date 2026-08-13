# shellcheck shell=bash

soviez_migration_token_eligibility_p20() {
  local account_id="$1" license_id="$2"
  soviez_migration_p20_ledger eligibility --account-id "$account_id" --license-id "$license_id"
}

soviez_migration_token_assert_canonical_only() {
  # Block obsolete disconnected consume env
  if [[ "${SOVIEZ_MIG_LEGACY_CONSUME:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_TOKEN_NOT_ELIGIBLE "legacy consume_ip_migration_token blocked; use commit_migration_authorization"
  fi
}
