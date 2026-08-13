# shellcheck shell=bash
# Phase 21 cutover write-freeze — distinct state file from Phase 19's
# transfer freeze (src/migration/final_sync/freeze.sh). 15-minute default
# hard timeout (SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS).

soviez_migration_cutover_freeze_path() {
  printf '%s/freeze.json\n' "$(soviez_migration_cutover_op_dir "$1")"
}

soviez_migration_cutover_freeze_start() {
  local pair_id="${1:-}" op_id="${2:-}"
  [[ -n "$pair_id" && -n "$op_id" ]] || soviez_migration_die MIGRATION_SOURCE_FREEZE_REQUIRED "pair-id and op-id required"
  local max="${SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS:-900}"
  local dir path
  dir="$(soviez_migration_cutover_op_dir "$op_id")"
  mkdir -p "$dir"
  path="$(soviez_migration_cutover_freeze_path "$op_id")"
  SOVIEZ_OUT="$path" SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_MAX="$max" python3 - <<'PY'
import json, os, datetime
started = datetime.datetime.utcnow()
doc = {
  "schema": "soviez.cutover_freeze.v1",
  "pair_id": os.environ["SOVIEZ_PAIR"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "state": "frozen",
  "started_at": started.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "max_seconds": int(os.environ["SOVIEZ_MAX"]),
  "expires_at": (started + datetime.timedelta(seconds=int(os.environ["SOVIEZ_MAX"]))).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "released": False,
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(doc, separators=(",", ":")))
PY
  cat "$path"
}

soviez_migration_cutover_freeze_release() {
  local op_id="${1:-}" reason="${2:-released}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_SOURCE_FREEZE_REQUIRED "op-id required"
  local path
  path="$(soviez_migration_cutover_freeze_path "$op_id")"
  if [[ ! -f "$path" ]]; then
    printf '{"released":true,"idempotent":true}\n'
    return 0
  fi
  SOVIEZ_P="$path" SOVIEZ_R="$reason" python3 - <<'PY'
import json, os, datetime
p = os.environ["SOVIEZ_P"]
d = json.load(open(p))
d["state"] = "released"
d["released"] = True
d["release_reason"] = os.environ["SOVIEZ_R"]
d["ended_at"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
open(p, "w").write(json.dumps(d, separators=(",", ":")))
PY
  cat "$path"
}

soviez_migration_cutover_freeze_check_timeout() {
  local op_id="${1:-}"
  local path
  path="$(soviez_migration_cutover_freeze_path "$op_id")"
  [[ -f "$path" ]] || return 0
  local released expires
  released="$(soviez_json_get "$(cat "$path")" released)"
  [[ "$released" == "true" || "$released" == "True" ]] && return 0
  expires="$(soviez_json_get "$(cat "$path")" expires_at)"
  if soviez_migration_is_expired "$expires"; then
    soviez_migration_cutover_freeze_release "$op_id" "timeout" >/dev/null
    soviez_migration_die MIGRATION_FINAL_CUTOVER_SYNC_TIMEOUT "cutover freeze exceeded max seconds"
  fi
  return 0
}
