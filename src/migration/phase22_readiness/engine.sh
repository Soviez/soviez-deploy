# shellcheck shell=bash
# Phase 22 readiness — POST-cutover report only (distinct from the PRE-cutover
# src/migration/phase21_readiness module). Never archives or purges the
# source; purely reports whether a future Phase 22 archive/purge op could be
# safely authorized. 24h TTL.

soviez_migration_phase22_readiness() {
  local auth_id="${1:-}"
  [[ -n "$auth_id" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization-id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_PHASE22_READINESS"
  soviez_migration_cutover_paths_init

  local authf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization missing"

  local blockers=() warnings=()
  local to
  to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$auth_id")" traffic_owner)"
  [[ "$to" == "destination" ]] || blockers+=("traffic_owner_not_destination")

  local st_state
  st_state="$(soviez_json_get "$(soviez_migration_source_transition_get "$auth_id")" state 2>/dev/null || true)"
  [[ "$st_state" == "cutover_maintenance" ]] || warnings+=("source_not_in_maintenance")

  local report_id status
  report_id="$(soviez_migration_new_id p22r)"
  if [[ ${#blockers[@]} -gt 0 ]]; then status=BLOCKED
  elif [[ ${#warnings[@]} -gt 0 ]]; then status=WARNING
  else status=PASS
  fi

  mkdir -p "$SOVIEZ_MIG_ROOT/phase22_readiness/$report_id"
  SOVIEZ_OUT="$SOVIEZ_MIG_ROOT/phase22_readiness/$report_id/report.json" \
    SOVIEZ_RID="$report_id" SOVIEZ_AID="$auth_id" SOVIEZ_ST="$status" \
    SOVIEZ_BL="$(printf '%s,' ${blockers[@]+"${blockers[@]}"})" \
    SOVIEZ_WN="$(printf '%s,' ${warnings[@]+"${warnings[@]}"})" \
    SOVIEZ_TTL="${SOVIEZ_MIG_P22_READINESS_TTL_SECONDS:-86400}" python3 - <<'PY'
import json, os, time, hashlib
bl = [x for x in os.environ.get("SOVIEZ_BL", "").split(",") if x]
wn = [x for x in os.environ.get("SOVIEZ_WN", "").split(",") if x]
exp = time.time() + int(os.environ["SOVIEZ_TTL"])
body = {
  "schema": "soviez.migration_phase22_readiness.v1",
  "report_id": os.environ["SOVIEZ_RID"],
  "authorization_id": os.environ["SOVIEZ_AID"],
  "readiness_status": os.environ["SOVIEZ_ST"],
  "archives_source": False,
  "purges_source": False,
  "blockers": bl,
  "warnings": wn,
  "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "expires_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(exp)),
  "signer": "soviez-p21",
}
body["public_signature"] = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(body, separators=(",", ":")))
PY
  cat "$SOVIEZ_MIG_ROOT/phase22_readiness/$report_id/report.json"
}

soviez_migration_phase22_readiness_show() {
  local report_id="${1:-}"
  [[ -n "$report_id" ]] || soviez_migration_die MIGRATION_PHASE22_NOT_READY "report-id required"
  local f="$SOVIEZ_MIG_ROOT/phase22_readiness/$report_id/report.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_PHASE22_NOT_READY "report missing"
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$f")" expires_at)"; then
    soviez_migration_die MIGRATION_PHASE22_NOT_READY "phase22 readiness report expired"
  fi
  cat "$f"
}
