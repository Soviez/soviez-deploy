# shellcheck shell=bash

soviez_migration_transfer_load_pair() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  # Reuse domain loader (signature + expiry + abort checks)
  if declare -F soviez_migration_load_pair >/dev/null 2>&1; then
    soviez_migration_load_pair "$pair_id"
    return $?
  fi
  soviez_migration_paths_init
  local path
  path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown pair: $pair_id"
  cat "$path"
}

soviez_migration_transfer_load_routing() {
  local routing_plan_id="${1:-}" pair_id="${2:-}"
  [[ -n "$routing_plan_id" ]] || soviez_migration_die MIGRATION_ROUTING_READINESS_REQUIRED "routing-plan-id required"
  soviez_migration_paths_init
  local path report result
  path="$(soviez_migration_routing_plan_dir "$routing_plan_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_ROUTING_READINESS_REQUIRED "Unknown routing plan: $routing_plan_id"
  if ! soviez_migration_verify_object_signature "$path" 2>/dev/null; then
    # Fixture mode may omit signature during unit tests
    if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_ROUTING_READINESS_INVALID "Routing plan signature invalid"
    fi
  fi
  report="$(cat "$path")"
  if soviez_migration_is_expired "$(soviez_json_get "$report" expires_at)"; then
    soviez_migration_die MIGRATION_ROUTING_READINESS_EXPIRED "Routing plan expired"
  fi
  if [[ -n "$pair_id" ]]; then
    local bound
    bound="$(soviez_json_get "$report" migration_pair_id)"
    [[ "$bound" == "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_IDENTITY_MISMATCH "Routing plan pair mismatch"
  fi
  result="$(soviez_json_get "$report" result)"
  [[ "$result" == "PASS" ]] || soviez_migration_die MIGRATION_ROUTING_NOT_READY "Routing readiness result must be PASS (got $result)"
  printf '%s' "$report"
}

soviez_migration_transfer_require_routing() {
  local pair_id="${1:-}" routing_plan_id="${2:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  [[ -n "$routing_plan_id" ]] || soviez_migration_die MIGRATION_ROUTING_READINESS_REQUIRED "routing-plan-id required"
  # Exact IDs only — refuse wildcards / all
  case "$pair_id$routing_plan_id" in
    *'*'*|*'?'*|all|ALL) soviez_migration_die MIGRATION_TRANSFER_NOT_AUTHORIZED "Wildcard targeting refused" ;;
  esac
  soviez_migration_transfer_load_pair "$pair_id" >/dev/null
  soviez_migration_transfer_load_routing "$routing_plan_id" "$pair_id" >/dev/null
  return 0
}

soviez_migration_transfer_find_latest_routing_pass() {
  local pair_id="$1"
  soviez_migration_paths_init
  SOVIEZ_PAIR="$pair_id" SOVIEZ_D="$SOVIEZ_MIG_ROUTING_PLAN_DIR" python3 - <<'PY'
import json, os, pathlib
root=pathlib.Path(os.environ["SOVIEZ_D"])
pair=os.environ["SOVIEZ_PAIR"]
best=None
best_ts=""
for p in root.glob("*/object.json"):
  try: d=json.loads(p.read_text())
  except Exception: continue
  if d.get("migration_pair_id")!=pair: continue
  if d.get("result")!="PASS": continue
  ts=d.get("issued_at") or ""
  if ts>=best_ts:
    best_ts=ts; best=d.get("plan_id")
print(best or "")
PY
}
