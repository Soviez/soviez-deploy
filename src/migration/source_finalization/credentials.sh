# shellcheck shell=bash

soviez_migration_p22_credentials_disposition() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/credentials.json"
  mkdir -p "$(dirname "$out")"
  if [[ "${SOVIEZ_MIG_P22_CREDENTIALS_INCOMPLETE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_CREDENTIAL_DISPOSITION_INCOMPLETE "credential disposition incomplete"
  fi
  # Record disposition — never silent destroy of all credentials as purge.
  printf '{"disposition_recorded":true,"destroyed":false,"rotated":false,"retained_inventory":true}\n' > "$out"
  cat "$out"
}

soviez_migration_source_credentials_status() {
  local archive_op_id="${1:-}"
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_LICENSE_FINALIZE"
  soviez_migration_p22_paths_init
  local f
  f="$(soviez_migration_p22_finalization_dir "$archive_op_id")/credentials.json"
  [[ -f "$f" ]] || printf '{"disposition_recorded":false}\n'
  [[ -f "$f" ]] && cat "$f"
}
