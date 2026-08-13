# shellcheck shell=bash

soviez_migration_p20_revalidate_phase19() {
  local pair_id="$1"
  local pair_dir staging_id ready freeze_path
  soviez_migration_p20_paths_init
  pair_dir="$(soviez_migration_pair_dir "$pair_id")"
  [[ -f "$pair_dir/object.json" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair missing"
  # freeze must be released
  if [[ -d "$SOVIEZ_MIG_ROOT/ops" ]]; then
    while IFS= read -r -d '' f; do
      if [[ -f "$f" ]]; then
        local rel
        rel="$(soviez_json_get "$(cat "$f")" released 2>/dev/null || echo true)"
        local active
        active="$(soviez_json_get "$(cat "$f")" active 2>/dev/null || echo false)"
        if [[ "$active" == "true" || "$active" == "True" ]] && [[ "$rel" != "true" && "$rel" != "True" ]]; then
          soviez_migration_die MIGRATION_PHASE19_DRIFT_DETECTED "source write freeze still active"
        fi
      fi
    done < <(find "$SOVIEZ_MIG_ROOT" -name 'WRITE_FREEZE.json' -print0 2>/dev/null || true)
  fi
  # Find latest transfer op with ready_for_20
  local op_state found=0 ready_val staging
  while IFS= read -r sf; do
    [[ -f "$sf" ]] || continue
    ready_val="$(soviez_json_get "$(cat "$sf")" ready_for_20 2>/dev/null || true)"
    staging="$(soviez_json_get "$(cat "$sf")" destination_staging_id 2>/dev/null || true)"
    local pid
    pid="$(soviez_json_get "$(cat "$sf")" migration_pair_id 2>/dev/null || true)"
    if [[ "$pid" == "$pair_id" && -n "$ready_val" ]]; then
      found=1
      if [[ "$ready_val" == "BLOCKED" ]]; then
        soviez_migration_die MIGRATION_PHASE19_READINESS_INVALID "ready_for_20=BLOCKED"
      fi
      if [[ "${SOVIEZ_MIG_P20_INJECT_DRIFT:-}" == "fingerprint" ]]; then
        soviez_migration_die MIGRATION_PHASE19_DRIFT_DETECTED "injected fingerprint drift"
      fi
      # public route check on staging
      if [[ -n "$staging" && -f "$(soviez_migration_staging_dir "$staging")/identity.json" ]]; then
        local pub
        pub="$(soviez_json_get "$(cat "$(soviez_migration_staging_dir "$staging")/identity.json")" public_routing_enabled)"
        if [[ "$pub" == "true" || "$pub" == "True" ]]; then
          soviez_migration_die MIGRATION_DESTINATION_PUBLIC_ROUTE_DETECTED "staging public route"
        fi
      fi
      printf '%s\n' "{\"pair_id\":\"$pair_id\",\"ready_for_20\":\"$ready_val\",\"staging_id\":\"${staging:-}\",\"ok\":true}"
      return 0
    fi
  done < <(find "$SOVIEZ_MIG_ROOT/ops" -name state.json 2>/dev/null | sort)
  # Fixture-friendly: allow explicit readiness env
  if [[ "${SOVIEZ_MIG_P20_FIXTURE_READY:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_P20_INJECT_DRIFT:-}" == "fingerprint" ]]; then
      soviez_migration_die MIGRATION_PHASE19_DRIFT_DETECTED "injected fingerprint drift"
    fi
    printf '%s\n' "{\"pair_id\":\"$pair_id\",\"ready_for_20\":\"${SOVIEZ_MIG_P20_FIXTURE_READY_VAL:-PASS}\",\"staging_id\":\"${SOVIEZ_MIG_P20_STAGING_ID:-staging-fixture}\",\"ok\":true}"
    return 0
  fi
  [[ "$found" -eq 1 ]] || soviez_migration_die MIGRATION_PHASE19_READINESS_REQUIRED "Phase 19 readiness missing for pair"
}
