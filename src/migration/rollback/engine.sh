# shellcheck shell=bash
# Phase 21 rollback tiers:
#   R0 — pre-commit abort (traffic_owner still source; no DNS change made yet)
#   R1 — post-commit, within window, zero meaningful writes/payment capture
#   R2 — post-commit, within window, dual-control required (T0+15m, OD-24)
#   R3 — MIGRATION_ROLLBACK_NOT_SAFE (window expired / meaningful writes /
#        payment side effect) — advisory/manual only, token never restored.

SOVIEZ_MIG_P21_DUAL_CONTROL_AFTER_SECONDS="${SOVIEZ_MIG_P21_DUAL_CONTROL_AFTER_SECONDS:-900}"

soviez_migration_rollback_eligibility() {
  local op_id="${1:-}" auth_id="${2:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "op-id required"
  soviez_migration_cutover_paths_init

  if [[ "${SOVIEZ_MIG_P21_MEANINGFUL_WRITES:-0}" == "1" ]]; then
    printf '{"eligible":false,"tier":"R3","code":"MIGRATION_ROLLBACK_NOT_SAFE","reason":"meaningful_writes"}\n'
    return 1
  fi
  if [[ "${SOVIEZ_MIG_P21_PAYMENT_CAPTURED:-0}" == "1" ]]; then
    printf '{"eligible":false,"tier":"R3","code":"MIGRATION_ROLLBACK_NOT_SAFE","reason":"payment_side_effect"}\n'
    return 1
  fi

  # Phase 22: if rollback window closed / automatic_rollback_allowed=false → not eligible.
  local closure_byc wf_closed
  if [[ -n "${SOVIEZ_MIG_ROOT:-}" ]]; then
    closure_byc="$SOVIEZ_MIG_ROOT/rollback_closure/by_cutover/${op_id}.json"
    if [[ -f "$closure_byc" ]]; then
      local ara
      ara="$(soviez_json_get "$(cat "$closure_byc")" automatic_rollback_allowed 2>/dev/null || echo true)"
      if [[ "$ara" == "False" || "$ara" == "false" ]]; then
        printf '{"eligible":false,"tier":"R3","code":"MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED","reason":"already_closed"}\n'
        return 1
      fi
    fi
  fi
  wf_closed="$(soviez_migration_cutover_rollback_window_path "$op_id")"
  if [[ -f "$wf_closed" ]]; then
    local closed_flag
    closed_flag="$(soviez_json_get "$(cat "$wf_closed")" automatic_rollback_allowed 2>/dev/null || echo true)"
    if [[ "$closed_flag" == "False" || "$closed_flag" == "false" ]]; then
      printf '{"eligible":false,"tier":"R3","code":"MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED","reason":"already_closed"}\n'
      return 1
    fi
  fi

  local wf window_expired=0
  wf="$(soviez_migration_cutover_rollback_window_path "$op_id")"
  if [[ -f "$wf" ]]; then
    local exp
    exp="$(soviez_json_get "$(cat "$wf")" expires_at)"
    soviez_migration_is_expired "$exp" && window_expired=1
  fi
  if [[ "$window_expired" -eq 1 ]]; then
    printf '{"eligible":false,"tier":"R3","code":"MIGRATION_ROLLBACK_WINDOW_EXPIRED","reason":"window_expired"}\n'
    return 1
  fi

  local to="source"
  [[ -n "$auth_id" ]] && to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$auth_id")" traffic_owner 2>/dev/null || echo source)"

  if [[ "$to" != "destination" ]]; then
    printf '{"eligible":true,"tier":"R0"}\n'
    return 0
  fi

  local elapsed=0
  if [[ -f "$wf" ]]; then
    local opened_epoch now_epoch
    opened_epoch="$(soviez_migration_iso_to_epoch "$(soviez_json_get "$(cat "$wf")" opened_at)" 2>/dev/null || echo 0)"
    now_epoch="$(soviez_migration_now_epoch)"
    elapsed=$((now_epoch - opened_epoch))
  fi
  if [[ "$elapsed" -ge "${SOVIEZ_MIG_P21_DUAL_CONTROL_AFTER_SECONDS}" ]]; then
    printf '{"eligible":true,"tier":"R2","dual_control_required":true}\n'
    return 0
  fi
  printf '{"eligible":true,"tier":"R1"}\n'
  return 0
}

# soviez_migration_rollback_run <pair-id> <op-id> <auth-id> <fqdn> [previous-dns-target] [dual-control-confirmed]
soviez_migration_rollback_run() {
  local pair_id="${1:-}" op_id="${2:-}" auth_id="${3:-}" fqdn="${4:-}" prev_target="${5:-}" dual_confirmed="${6:-0}"
  [[ -n "$op_id" && -n "$auth_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "op-id and authorization-id required"
  soviez_migration_cutover_paths_init
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_IMMEDIATE_ROLLBACK"

  local elig erc
  set +e
  elig="$(soviez_migration_rollback_eligibility "$op_id" "$auth_id")"
  erc=$?
  set -e
  if [[ "$erc" -ne 0 ]]; then
    local code
    code="$(soviez_json_get "$elig" code)"
    soviez_migration_die "$code" "rollback not eligible: $(soviez_json_get "$elig" reason)"
  fi

  local tier
  tier="$(soviez_json_get "$elig" tier)"
  if [[ "$tier" == "R2" && "$dual_confirmed" != "1" ]]; then
    soviez_migration_die MIGRATION_ROLLBACK_NOT_ELIGIBLE "dual-control confirmation required after T0+15m (OD-24)"
  fi

  if [[ -n "$fqdn" && -n "$prev_target" ]]; then
    ( soviez_migration_p21_dns_rollback "$fqdn" "$prev_target" ) >/dev/null 2>&1 || true
  fi
  soviez_migration_p21_nginx_disable_production || true
  soviez_migration_stage_cutover_disable "$pair_id" >/dev/null || true
  soviez_migration_source_transition_to_rollback_origin "$auth_id" >/dev/null
  soviez_migration_traffic_owner_switch "$auth_id" source >/dev/null

  printf '{"status":"rolled_back","tier":"%s","traffic_owner":"source","migration_token_consumed":true,"token_restored":false}\n' "$tier"
}

# AR-04 split-brain / AR-01 health flapping automatic trigger evaluation.
# Returns 0 with a trigger payload when rollback is recommended/required.
soviez_migration_rollback_auto_check() {
  local auth_id="${1:-}"
  if [[ "${SOVIEZ_MIG_P21_SPLIT_BRAIN:-0}" == "1" ]]; then
    printf '{"trigger":"AR-04","action":"rollback_required","enforced":true}\n'
    return 0
  fi
  if [[ "${SOVIEZ_MIG_P21_HEALTH_FLAPPING:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_P21_POST_WINDOW:-0}" == "1" ]]; then
      printf '{"trigger":"AR-01","action":"advisory_only"}\n'
    else
      printf '{"trigger":"AR-01","action":"suppressed_grace_period"}\n'
    fi
    return 0
  fi
  printf '{"trigger":"none"}\n'
  return 1
}
