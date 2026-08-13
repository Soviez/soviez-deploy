# shellcheck shell=bash

soviez_migration_addons_verify() {
  local op_id="$1"
  local out_dir
  out_dir="$(soviez_migration_transfer_op_dir "$op_id")/addons"
  [[ -d "$out_dir" ]] || soviez_migration_die MIGRATION_ADDON_TRANSFER_FAILED "Addon transfer missing"
  shopt -s nullglob
  for f in "$out_dir"/*.resolved.json; do
    local approved
    approved="$(soviez_json_get "$(cat "$f")" approved)"
    [[ "$approved" == "true" || "$approved" == "True" ]] || \
      soviez_migration_die MIGRATION_ADDON_NOT_APPROVED "Addon not approved: $f"
    local digest
    digest="$(soviez_json_get "$(cat "$f")" digest)"
    [[ -n "$digest" && "$digest" != "null" ]] || \
      soviez_migration_die MIGRATION_ADDON_SIGNATURE_INVALID "Missing digest"
  done
  printf '{"status":"verified"}\n'
}
