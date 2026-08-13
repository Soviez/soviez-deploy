# shellcheck shell=bash
# Resolve cutover op + auth + phase22 readiness for stabilization targeting.

soviez_migration_p22_resolve_cutover() {
  local cutover_id="${1:-}"
  [[ -n "$cutover_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "cutover-id required"
  soviez_migration_p22_paths_init
  local stf
  stf="$(soviez_migration_cutover_state_path "$cutover_id")"
  [[ -f "$stf" ]] || soviez_migration_die MIGRATION_NOT_FOUND "cutover operation not found: $cutover_id"
  cat "$stf"
}

soviez_migration_p22_require_phase21_cutover() {
  local cutover_id="${1:-}"
  local st auth_id to state
  st="$(soviez_migration_p22_resolve_cutover "$cutover_id")"
  state="$(soviez_json_get "$st" current_state)"
  [[ "$state" == "cutover_complete" ]] || \
    soviez_migration_die MIGRATION_PHASE21_READINESS_REQUIRED "cutover not complete: $state"
  auth_id="$(soviez_json_get "$st" authorization_id)"
  to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$auth_id")" traffic_owner)"
  [[ "$to" == "destination" ]] || \
    soviez_migration_die MIGRATION_PHASE21_READINESS_INVALID "traffic_owner must be destination"
  printf '%s\n' "$st"
}

soviez_migration_p22_require_readiness() {
  local auth_id="${1:-}"
  local report_path latest status
  # Prefer newest non-expired phase22 readiness report for this auth.
  latest=""
  if [[ -d "$SOVIEZ_MIG_ROOT/phase22_readiness" ]]; then
    while IFS= read -r -d '' f; do
      if [[ "$(soviez_json_get "$(cat "$f")" authorization_id 2>/dev/null || true)" == "$auth_id" ]]; then
        if ! soviez_migration_is_expired "$(soviez_json_get "$(cat "$f")" expires_at)"; then
          latest="$f"
        fi
      fi
    done < <(find "$SOVIEZ_MIG_ROOT/phase22_readiness" -name report.json -print0 2>/dev/null | sort -z)
  fi
  # Also accept cutover-embedded readiness.
  if [[ -z "$latest" ]]; then
    local op_id
    op_id="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$auth_id")" operation_id 2>/dev/null || true)"
    if [[ -n "$op_id" && -f "$(soviez_migration_cutover_op_dir "$op_id")/phase22_readiness.json" ]]; then
      latest="$(soviez_migration_cutover_op_dir "$op_id")/phase22_readiness.json"
      if soviez_migration_is_expired "$(soviez_json_get "$(cat "$latest")" expires_at 2>/dev/null || echo 1970-01-01T00:00:00Z)"; then
        soviez_migration_die MIGRATION_PHASE21_READINESS_EXPIRED "embedded phase22 readiness expired"
      fi
    fi
  fi
  [[ -n "$latest" ]] || soviez_migration_die MIGRATION_PHASE21_READINESS_REQUIRED "phase22 readiness report required"
  status="$(soviez_json_get "$(cat "$latest")" readiness_status)"
  [[ "$status" == "PASS" || "$status" == "WARNING" ]] || \
    soviez_migration_die MIGRATION_PHASE21_READINESS_INVALID "phase22 readiness status=$status"
  cat "$latest"
}
