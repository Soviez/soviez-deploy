# shellcheck shell=bash
# Phase 21 traffic_owner record — the single authoritative signal for who owns
# live Production traffic. Idempotent switch; source is the implicit default.

soviez_migration_traffic_owner_get() {
  local id="${1:-}"
  [[ -n "$id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "traffic_owner id required"
  soviez_migration_cutover_paths_init
  local f
  f="$(soviez_migration_traffic_owner_path "$id")"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    printf '{"schema":"soviez.traffic_owner.v1","id":"%s","traffic_owner":"source","switched_at":null}\n' "$id"
  fi
}

soviez_migration_traffic_owner_switch() {
  local id="${1:-}" target="${2:-destination}" op_id="${3:-}"
  [[ -n "$id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "traffic_owner id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_TRAFFIC_OWNER_SWITCH"
  soviez_migration_cutover_paths_init

  local f cur cur_owner
  f="$(soviez_migration_traffic_owner_path "$id")"
  cur="$(soviez_migration_traffic_owner_get "$id")"
  cur_owner="$(soviez_json_get "$cur" traffic_owner)"

  if [[ "$cur_owner" == "$target" ]]; then
    # Idempotent — traffic_cutover_started exactly once semantics.
    cat "$f"
    return 0
  fi

  SOVIEZ_OUT="$f" SOVIEZ_ID="$id" SOVIEZ_TO="$target" SOVIEZ_FROM="$cur_owner" SOVIEZ_OP="$op_id" python3 - <<'PY'
import json, os, time
body = {
  "schema": "soviez.traffic_owner.v1",
  "id": os.environ["SOVIEZ_ID"],
  "traffic_owner": os.environ["SOVIEZ_TO"],
  "previous_owner": os.environ["SOVIEZ_FROM"],
  "operation_id": os.environ.get("SOVIEZ_OP") or None,
  "switched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$f"
  cat "$f"
}
