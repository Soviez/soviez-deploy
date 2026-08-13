# shellcheck shell=bash

soviez_migration_rollback_window_close_commit() {
  local cutover_id="${1:-}"
  local st auth_id op_id byc
  st="$(soviez_migration_p22_require_phase21_cutover "$cutover_id")"
  auth_id="$(soviez_json_get "$st" authorization_id)"

  # Idempotent: same receipt on retry.
  byc="$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
  if [[ -f "$byc" ]] && [[ "$(soviez_json_get "$(cat "$byc")" automatic_rollback_allowed)" == "False" || "$(soviez_json_get "$(cat "$byc")" automatic_rollback_allowed)" == "false" ]]; then
    cat "$byc"
    return 0
  fi

  op_id="$(soviez_migration_new_id p22rc)"
  soviez_migration_rollback_window_write_receipt "$op_id" "$cutover_id" "$auth_id"
}
