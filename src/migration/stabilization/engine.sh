# shellcheck shell=bash
# Phase 22 destination stabilization — sustained observation over configured duration.

soviez_migration_stabilization_status() {
  local cutover_id="${1:-}"
  soviez_migration_p22_paths_init
  SOVIEZ_MIG_P22_MUTATING=0 soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_STABILIZATION"
  local st auth_id
  st="$(soviez_migration_p22_require_phase21_cutover "$cutover_id")"
  auth_id="$(soviez_json_get "$st" authorization_id)"
  soviez_migration_p22_require_readiness "$auth_id" >/dev/null

  local report_id duration started_epoch ended_epoch samples_file tick sample ok_all=1 waited
  report_id="$(soviez_migration_new_id p22s)"
  duration="${SOVIEZ_MIG_P22_STABILIZATION_SECONDS:-86400}"
  tick="${SOVIEZ_MIG_P22_OBSERVE_TICK_SECONDS:-1}"
  [[ "$tick" -gt 0 ]] || tick=1
  # Fixture safety: never spin 86400 python ticks in certification unless explicitly requested.
  if [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "$duration" -gt 120 && "${SOVIEZ_MIG_P22_ALLOW_LONG_STAB:-0}" != "1" ]]; then
    duration=10
  fi
  # Cap sample count: use larger effective ticks so we get ≥2 samples without O(duration) cost.
  local max_samples=12
  if [[ $((duration / tick)) -gt $max_samples ]]; then
    tick=$(( (duration + max_samples - 1) / max_samples ))
    [[ "$tick" -gt 0 ]] || tick=1
  fi
  samples_file="$(soviez_migration_p22_stab_dir "$report_id")/samples.ndjson"
  mkdir -p "$(dirname "$samples_file")"
  : > "$samples_file"

  started_epoch="$(soviez_migration_p22_now_epoch)"
  waited=0
  # Multi-tick observation loop: record a sample each tick across the full duration.
  # Cert-clock fixtures advance time per tick instead of sleeping wall-clock.
  while true; do
    sample="$(soviez_migration_p22_observe_once "$cutover_id")"
    printf '%s\n' "$sample" >> "$samples_file"
    if ! soviez_migration_p22_health_sample_ok "$sample" \
      || ! soviez_migration_p22_traffic_checks "$sample" \
      || ! soviez_migration_p22_integrations_ok "$sample" \
      || ! soviez_migration_p22_backups_ok "$sample" \
      || ! soviez_migration_p22_stages_ok "$sample" \
      || ! soviez_migration_p22_incidents_clear "$sample"; then
      ok_all=0
    fi

    if [[ "$waited" -ge "$duration" ]]; then
      break
    fi

    if [[ "${SOVIEZ_MIG_P22_FIXTURE:-0}" == "1" && "${SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK:-0}" == "1" ]]; then
      soviez_migration_p22_advance_cert_clock "$tick"
    else
      sleep "$tick"
    fi
    waited=$((waited + tick))
  done

  ended_epoch="$(soviez_migration_p22_now_epoch)"
  soviez_migration_p22_validate_observation_window "$started_epoch" "$ended_epoch" "$duration"

  # Require multiple samples — a single instantaneous check is insufficient.
  local sample_count
  sample_count="$(wc -l < "$samples_file" | tr -d ' ')"
  [[ "$sample_count" -ge 2 ]] || \
    soviez_migration_die MIGRATION_STABILIZATION_INCOMPLETE \
      "observation recorded ${sample_count} sample(s); need multiple ticks over duration"

  local status=PASS
  if [[ "$ok_all" -ne 1 ]]; then
    status=FAIL
  fi
  local report
  report="$(soviez_migration_p22_stabilization_write_report "$report_id" "$cutover_id" "$auth_id" "$status" "$samples_file")"
  # Index by cutover for lookups.
  mkdir -p "$(soviez_migration_p22_stab_dir "by_cutover")"
  printf '%s\n' "$report_id" > "$(soviez_migration_p22_stab_dir "by_cutover")/${cutover_id}.id"
  if [[ "$status" != "PASS" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_HEALTH_UNSTABLE "stabilization failed"
  fi
  printf '%s\n' "$report"
}

soviez_migration_stabilization_latest_report() {
  local cutover_id="${1:-}"
  soviez_migration_p22_paths_init
  local idf rid
  idf="$(soviez_migration_p22_stab_dir "by_cutover")/${cutover_id}.id"
  [[ -f "$idf" ]] || soviez_migration_die MIGRATION_STABILIZATION_REQUIRED "no stabilization report for cutover"
  rid="$(tr -d '[:space:]' < "$idf")"
  cat "$(soviez_migration_p22_stab_dir "$rid")/report.json"
}
