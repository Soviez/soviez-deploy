# shellcheck shell=bash
# Phase 21 optional public Stage cutover — only for Stages already selected
# in earlier phases. Skips cleanly when none are selected.

soviez_migration_stage_cutover_selected() {
  printf '%s\n' "${SOVIEZ_MIG_P21_STAGE_IDS:-}"
}

soviez_migration_stage_cutover_run() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_STAGE_CUTOVER"

  local ids mandatory fail_ids
  ids="${SOVIEZ_MIG_P21_STAGE_IDS:-}"
  mandatory="${SOVIEZ_MIG_P21_STAGE_MANDATORY_IDS:-}"
  fail_ids="${SOVIEZ_MIG_P21_STAGE_FAIL_IDS:-}"

  if [[ -z "$ids" ]]; then
    printf '{"status":"skipped","reason":"no_stages_selected"}\n'
    return 0
  fi

  local id m blocked=0 warn=0
  for id in ${ids//,/ }; do
    local is_mandatory=0 fail=0
    for m in ${mandatory//,/ }; do [[ "$m" == "$id" ]] && is_mandatory=1; done
    for m in ${fail_ids//,/ }; do [[ "$m" == "$id" ]] && fail=1; done
    if [[ "$fail" -eq 1 ]]; then
      if [[ "$is_mandatory" -eq 1 ]]; then blocked=1; else warn=1; fi
    fi
  done

  if [[ "$blocked" -eq 1 ]]; then
    soviez_migration_die MIGRATION_STAGE_CUTOVER_MANDATORY_FAILED "mandatory Stage public cutover failed"
  fi

  local status="PASS"
  [[ "$warn" -eq 1 ]] && status="WARNING"
  printf '{"status":"%s","stage_ids":"%s"}\n' "$status" "$ids"
}

soviez_migration_stage_cutover_disable() {
  local pair_id="${1:-}"
  printf '{"pair_id":"%s","stage_public_routes":"disabled"}\n' "$pair_id"
}
