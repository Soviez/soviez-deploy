# shellcheck shell=bash

soviez_ops_lock_id() {
  local kind="$1" resource="$2"
  resource="$(printf '%s' "$resource" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._:-')"
  [[ -n "$resource" ]] || soviez_ops_die OPERATION_RESOURCE_CONFLICT "Invalid lock resource"
  printf '%s:%s\n' "$kind" "$resource"
}
soviez_ops_lock_dir() { printf '%s/%s\n' "$SOVIEZ_OPS_LOCKS_DIR" "$(printf '%s' "$1" | tr ':' '_' | tr -cd 'a-zA-Z0-9._-')"; }

soviez_ops_lock_acquire() {
  local op_id="$1" lock_id="$2" dir; dir="$(soviez_ops_lock_dir "$lock_id")"
  if mkdir "$dir" 2>/dev/null; then
    SOVIEZ_OWNER="$op_id" SOVIEZ_LOCK="$lock_id" SOVIEZ_NOW="$(soviez_ops_now_utc)" python3 - <<'PY' > "$dir/owner.json"
import json, os
print(json.dumps({"operation_id":os.environ["SOVIEZ_OWNER"],"lock_id":os.environ["SOVIEZ_LOCK"],"pid":os.getpid(),"generation":1,"acquired_at":os.environ["SOVIEZ_NOW"]},separators=(",",":")))
PY
    chmod 700 "$dir"; chmod 600 "$dir/owner.json"; return 0
  fi
  local owner owner_id; owner="$(cat "$dir/owner.json" 2>/dev/null || true)"; owner_id="$(soviez_json_get "$owner" operation_id 2>/dev/null || true)"
  if [[ -n "$owner_id" ]] && soviez_ops_heartbeat_stale "$owner_id" 2>/dev/null && ! kill -0 "$(soviez_json_get "$owner" pid 2>/dev/null || echo 0)" 2>/dev/null; then
    soviez_ops_die OPERATION_LOCK_STALE "Stale lock requires reconciliation: $lock_id"
  fi
  soviez_ops_die OPERATION_LOCK_CONFLICT "Resource lock held: $lock_id"
}
soviez_ops_lock_release() {
  local op_id="$1" lock_id="$2" dir owner
  dir="$(soviez_ops_lock_dir "$lock_id")"; owner="$(cat "$dir/owner.json" 2>/dev/null || true)"
  [[ "$(soviez_json_get "$owner" operation_id 2>/dev/null || true)" == "$op_id" ]] || soviez_ops_die OPERATION_RESOURCE_CONFLICT "Lock not owned by operation"
  rm -f "$dir/owner.json"; rmdir "$dir"
}
soviez_ops_lock_held_by() { soviez_json_get "$(cat "$(soviez_ops_lock_dir "$1")/owner.json")" operation_id; }
soviez_ops_locks_acquire_ordered() {
  local op_id="$1"; shift
  local lock; while IFS= read -r lock; do soviez_ops_lock_acquire "$op_id" "$lock"; done < <(printf '%s\n' "$@" | LC_ALL=C sort)
}
