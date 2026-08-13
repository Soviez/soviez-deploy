# shellcheck shell=bash

soviez_migration_p22_archive_resolve_source() {
  local source_id="${1:-}"
  [[ -n "$source_id" ]] || soviez_migration_die MIGRATION_SOURCE_REQUIRED "source-id required"
  # source_id may be cutover op id OR production/source id mapped via env.
  local cutover_id="${SOVIEZ_MIG_P22_CUTOVER_ID:-$source_id}"
  local st
  st="$(soviez_migration_p22_require_phase21_cutover "$cutover_id")"
  # Rollback window must be closed.
  local byc
  byc="$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
  [[ -f "$byc" ]] || soviez_migration_die MIGRATION_ROLLBACK_WINDOW_STILL_REQUIRED "rollback window not closed"
  local ara
  ara="$(soviez_json_get "$(cat "$byc")" automatic_rollback_allowed)"
  [[ "$ara" == "False" || "$ara" == "false" ]] || \
    soviez_migration_die MIGRATION_ROLLBACK_WINDOW_STILL_REQUIRED "automatic rollback still allowed"
  printf '%s\n' "$st"
}
