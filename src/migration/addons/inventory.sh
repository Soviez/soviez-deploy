# shellcheck shell=bash

soviez_migration_addons_inventory() {
  local pair_id="$1"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_ADDONS_JSON:-}" ]]; then
    printf '%s\n' "$SOVIEZ_MIG_FIXTURE_ADDONS_JSON"
    return 0
  fi
  printf '{"addons":[],"source":"empty"}\n'
}
