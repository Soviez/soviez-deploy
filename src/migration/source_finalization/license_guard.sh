# shellcheck shell=bash

soviez_migration_p22_license_guard_archived() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/license_guard_archived.json"
  mkdir -p "$(dirname "$out")"
  printf '{"mode":"archived","deny_production_login":true,"production_login_flags_denied":true}\n' > "$out"
  cat "$out"
}

# Guard check used by accidental-start denial.
soviez_migration_p22_assert_not_archived_login() {
  local source_id="${1:-}"
  local f
  f="$SOVIEZ_MIG_SOURCE_FINALIZATION_DIR/${source_id}/license_guard_archived.json"
  # Also scan by archive op.
  if [[ -f "$f" ]] && [[ "$(soviez_json_get "$(cat "$f")" deny_production_login)" == "True" || "$(soviez_json_get "$(cat "$f")" deny_production_login)" == "true" ]]; then
    if [[ "${SOVIEZ_MIG_P22_ALLOW_ARCHIVED_LOGIN:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_SOURCE_RUNTIME_SUSPEND_FAILED "archived source denies Production login"
    fi
  fi
}
