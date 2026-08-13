# shellcheck shell=bash

soviez_restore_rollback() {
  local op_id="$1"
  local pdir man
  soviez_restore_paths_init
  pdir="$(soviez_restore_preserve_dir "$op_id")"
  man="$pdir/rollback_manifest.json"
  [[ -f "$man" ]] || soviez_restore_die RESTORE_ROLLBACK_FAILED "No rollback manifest"

  if [[ "${SOVIEZ_RESTORE_FIXTURE_ROLLBACK_FAIL:-0}" == "1" ]]; then
    soviez_restore_die RESTORE_ROLLBACK_FAILED "Injected rollback failure"
  fi

  local tenant_id previous_digest prod_json db_path fs_path
  tenant_id="$(soviez_json_get "$(cat "$man")" tenant_id)"
  previous_digest="$(soviez_json_get "$(cat "$man")" previous_digest)"
  if [[ -f "$pdir/config/production_identity.json" ]]; then
    prod_json="$(cat "$pdir/config/production_identity.json")"
    db_path="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"
    fs_path="$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || true)"
  fi

  local runtime_dir="${SOVIEZ_TENANT_DIR:-${SOVIEZ_ROOT:-/var/soviez}/tenant}/$tenant_id"
  mkdir -p "$runtime_dir"
  printf '%s' "$previous_digest" > "$runtime_dir/current_digest.txt"

  if [[ -n "$db_path" && -d "$pdir/db" ]]; then
    mkdir -p "$db_path"
    cp -a "$pdir/db/." "$db_path/" 2>/dev/null || true
  fi
  if [[ -n "$fs_path" && -d "$pdir/filestore" ]]; then
    mkdir -p "$fs_path"
    cp -a "$pdir/filestore/." "$fs_path/" 2>/dev/null || true
  fi

  soviez_restore_candidate_cleanup "$op_id" || true
  SOVIEZ_T="$tenant_id" SOVIEZ_D="$previous_digest" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "RESTORE_ROLLED_BACK",
  "tenant_id": os.environ["SOVIEZ_T"],
  "restored_digest": os.environ["SOVIEZ_D"],
}, separators=(",", ":")))
PY
}

soviez_restore_safety_window_info() {
  local op_id="$1"
  local man hours
  man="$(soviez_restore_preserve_dir "$op_id")/rollback_manifest.json"
  [[ -f "$man" ]] || { printf '{"rollback_available":false}\n'; return 0; }
  hours="${SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS:-24}"
  SOVIEZ_M="$(cat "$man")" SOVIEZ_H="$hours" python3 - <<'PY'
import json, os
from datetime import datetime, timedelta, timezone
m = json.loads(os.environ["SOVIEZ_M"])
created = m.get("created_at") or ""
hours = int(os.environ["SOVIEZ_H"])
try:
  dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
except Exception:
  dt = datetime.now(timezone.utc)
expires = (dt + timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
now = datetime.now(timezone.utc)
available = now <= datetime.fromisoformat(expires.replace("Z", "+00:00"))
print(json.dumps({
  "rollback_available": available,
  "safety_window_hours": hours,
  "expires_at": expires,
}, separators=(",", ":")))
PY
}
