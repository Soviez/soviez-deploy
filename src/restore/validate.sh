# shellcheck shell=bash

soviez_restore_validate_candidate() {
  # Args: op_id production_json
  local op_id="$1" prod="$2"
  local cdir
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  [[ -d "$cdir/db" ]] || soviez_restore_die RESTORE_VALIDATION_FAILED "Candidate DB missing"
  [[ -d "$cdir/filestore" ]] || soviez_restore_die RESTORE_VALIDATION_FAILED "Candidate filestore missing"
  [[ -f "$cdir/candidate.json" ]] || soviez_restore_die RESTORE_VALIDATION_FAILED "Candidate identity missing"

  local slot
  slot="$(soviez_json_get "$(cat "$cdir/candidate.json")" license_slot_consumed 2>/dev/null || echo false)"
  [[ "$slot" == "false" || "$slot" == "False" || "$slot" == "0" ]] \
    || soviez_restore_die RESTORE_VALIDATION_FAILED "Candidate must not consume License slot"

  if [[ -f "$cdir/runtime/license_guard_identity.json" ]]; then
    local nonsell
    nonsell="$(soviez_json_get "$(cat "$cdir/runtime/license_guard_identity.json")" non_sellable 2>/dev/null || echo true)"
    [[ "$nonsell" == "true" || "$nonsell" == "True" ]] \
      || soviez_restore_die RESTORE_VALIDATION_FAILED "LG identity must be non_sellable"
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'validated=1\n' > "$cdir/runtime/validated"
  fi

  # Manifest signature already verified in compatibility path; re-check backup components
  local backup_id prod_id
  backup_id="$(cat "$cdir/runtime/backup_id.txt" 2>/dev/null || true)"
  if [[ -n "$backup_id" ]] && declare -F soviez_backup_manifest_verify >/dev/null 2>&1; then
    prod_id="$(soviez_json_get "$prod" tenant_id)"
    local man
    man="$(soviez_backup_dir "$prod_id" "$backup_id")/manifest.json"
    [[ -f "$man" ]] && soviez_backup_manifest_verify "$man"
  fi

  printf '%s' '{"ok":true,"validated":true}'
}
