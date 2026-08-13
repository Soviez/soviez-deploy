# shellcheck shell=bash

soviez_migration_p22_disable_routing() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/routing.json"
  mkdir -p "$(dirname "$out")"
  if [[ "${SOVIEZ_MIG_P22_INJECT_PUBLIC_ROUTE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_PUBLIC_ROUTE_STILL_ACTIVE "source public route still active"
  fi
  printf '{"public_route_disabled":true,"destination_binding_unchanged":true}\n' > "$out"
  cat "$out"
}
