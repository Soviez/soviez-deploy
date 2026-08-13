# shellcheck shell=bash
# Phase 21 pre-cutover revalidation of Phase 20 committed state.

soviez_migration_p21_find_auth_for_pair() {
  local pair_id="$1"
  local f pid status best=""
  [[ -d "$SOVIEZ_MIG_ROOT/authorization" ]] || return 1
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    pid="$(soviez_json_get "$(cat "$f")" migration_pair_id 2>/dev/null || true)"
    [[ "$pid" == "$pair_id" ]] || continue
    status="$(soviez_json_get "$(cat "$f")" transaction_status 2>/dev/null || true)"
    [[ "$status" == "committed" ]] || continue
    best="$(soviez_json_get "$(cat "$f")" authorization_id 2>/dev/null || true)"
  done < <(find "$SOVIEZ_MIG_ROOT/authorization" -mindepth 2 -maxdepth 2 -name authorization.json 2>/dev/null | sort)
  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

# soviez_migration_p21_revalidate_phase20 <pair_id>
# Requires: committed Phase 20 authorization, destination activation,
# source migration_origin_grace, destination verified backup, and either
# SOVIEZ_MIG_P21_FIXTURE=1 (disposable fixture — no live Phase 21 readiness
# report required) OR a real Phase 21 readiness report that is not BLOCKED.
soviez_migration_p21_revalidate_phase20() {
  local pair_id="$1"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_cutover_paths_init

  local auth_id="${SOVIEZ_MIG_P21_AUTH_ID:-}"
  if [[ -z "$auth_id" ]]; then
    auth_id="$(soviez_migration_p21_find_auth_for_pair "$pair_id")" || \
      soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "no committed Phase 20 authorization for pair"
  fi

  local authf actf gracef bakf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization missing"

  actf="$SOVIEZ_MIG_ROOT/activation/$auth_id/activation.json"
  [[ -f "$actf" ]] || soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_FAILED "destination activation missing"

  local license_id
  license_id="$(soviez_json_get "$(cat "$authf")" license_id)"
  gracef="$SOVIEZ_MIG_ROOT/grace/$license_id/grace.json"
  [[ -f "$gracef" ]] || soviez_migration_die MIGRATION_SOURCE_GRACE_INVALID "source migration_origin_grace missing"

  bakf="$SOVIEZ_MIG_ROOT/activation/$auth_id/backup/backup.json"
  [[ -f "$bakf" ]] || soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_FAILED "destination verified backup missing"

  if [[ "${SOVIEZ_MIG_P21_INJECT_DRIFT:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_CUTOVER_DRIFT_DETECTED "injected pre-cutover drift"
  fi

  local pub
  pub="$(soviez_json_get "$(cat "$actf")" public_route)"
  if [[ "$pub" == "true" || "$pub" == "True" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_PUBLIC_ROUTE_DETECTED "destination already public before cutover"
  fi

  # Token ledger must show fully consumed (Phase 20 canonical commit already ran).
  local snap rem slots
  snap="$(soviez_migration_p20_ledger snapshot --license-id "$license_id")"
  rem="$(soviez_json_get "$snap" grant_remaining)"
  slots="$(soviez_json_get "$snap" slot_count)"
  [[ "$rem" == "0" ]] || soviez_migration_die MIGRATION_TOKEN_NOT_CONSUMED "migration token not fully consumed"
  [[ "$slots" == "1" ]] || soviez_migration_die MIGRATION_SLOT_FORBIDDEN "unexpected slot_count for cutover"

  local readiness_status="FIXTURE"
  if [[ "${SOVIEZ_MIG_P21_FIXTURE:-0}" != "1" ]]; then
    local rid report
    rid="${SOVIEZ_MIG_P21_READINESS_REPORT_ID:-}"
    [[ -n "$rid" ]] || soviez_migration_die MIGRATION_PHASE21_NOT_READY "phase21 readiness report id required"
    report="$(soviez_migration_phase21_readiness_show "$rid")"
    readiness_status="$(soviez_json_get "$report" readiness_status)"
    [[ "$readiness_status" != "BLOCKED" ]] || soviez_migration_die MIGRATION_PHASE21_NOT_READY "phase21 readiness BLOCKED"
  fi

  SOVIEZ_PAIR="$pair_id" SOVIEZ_AUTH="$auth_id" SOVIEZ_LIC="$license_id" SOVIEZ_RS="$readiness_status" \
    python3 - <<'PY'
import json, os
print(json.dumps({
  "pair_id": os.environ["SOVIEZ_PAIR"],
  "authorization_id": os.environ["SOVIEZ_AUTH"],
  "license_id": os.environ["SOVIEZ_LIC"],
  "readiness_status": os.environ["SOVIEZ_RS"],
  "grace_ok": True,
  "activation_ok": True,
  "backup_ok": True,
  "token_consumed": True,
  "ok": True,
}, separators=(",", ":")))
PY
}
