# shellcheck shell=bash

soviez_update_rollback() {
  local op_id="$1"
  local man bdir
  man="$(soviez_update_rollback_manifest "$op_id")"
  bdir="$(soviez_update_backup_dir "$op_id")"
  [[ -f "$man" ]] || soviez_update_die UPDATE_ROLLBACK_FAILED "No rollback manifest"
  local tenant_id previous_digest
  tenant_id="$(soviez_json_get "$(cat "$man")" tenant_id)"
  previous_digest="$(soviez_json_get "$(cat "$man")" previous_digest)"

  if [[ "${SOVIEZ_UPDATE_FIXTURE_ROLLBACK_FAIL:-0}" == "1" ]]; then
    soviez_update_die UPDATE_ROLLBACK_FAILED "Injected rollback failure"
  fi

  local runtime_dir="${SOVIEZ_TENANT_DIR:-$SOVIEZ_ROOT/tenant}/$tenant_id"
  mkdir -p "$runtime_dir"
  printf '%s' "$previous_digest" > "$runtime_dir/current_digest.txt"
  if [[ -f "$runtime_dir/identity.json" ]]; then
    SOVIEZ_ID="$(cat "$runtime_dir/identity.json")" SOVIEZ_D="$previous_digest" python3 - <<'PY' > "$runtime_dir/identity.json.tmp"
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
d["current_digest"]=os.environ["SOVIEZ_D"]
d["image_digest"]=os.environ["SOVIEZ_D"]
print(json.dumps(d,separators=(",",":")))
PY
    mv "$runtime_dir/identity.json.tmp" "$runtime_dir/identity.json"
  fi

  # Restore DB/filestore from recovery set when Production was mutated (post-switch)
  local db_path fs_path
  if [[ -f "$bdir/config/production_identity.json" ]]; then
    db_path="$(soviez_json_get "$(cat "$bdir/config/production_identity.json")" database_path 2>/dev/null || true)"
    fs_path="$(soviez_json_get "$(cat "$bdir/config/production_identity.json")" filestore_path 2>/dev/null || true)"
  fi
  if [[ -n "$db_path" && -d "$bdir/db" ]]; then
    mkdir -p "$db_path"
    # Only restore into the exact Production paths recorded — never other tenants
    cp -a "$bdir/db/." "$db_path/" 2>/dev/null || true
  fi
  if [[ -n "$fs_path" && -d "$bdir/filestore" ]]; then
    mkdir -p "$fs_path"
    cp -a "$bdir/filestore/." "$fs_path/" 2>/dev/null || true
  fi

  soviez_update_candidate_cleanup "$op_id" || true

  SOVIEZ_T="$tenant_id" SOVIEZ_D="$previous_digest" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/rollback.json"
import json,os
print(json.dumps({
  "ok":True,
  "tenant_id":os.environ["SOVIEZ_T"],
  "restored_digest":os.environ["SOVIEZ_D"],
  "boundary":"lossless_if_no_post_switch_business_writes; after business writes rollback restores pre-switch snapshot only",
},separators=(",",":")))
PY
  cat "$(soviez_update_op_dir "$op_id")/rollback.json"
}

soviez_update_safety_window_info() {
  local op_id="$1"
  local man hours expires
  man="$(soviez_update_rollback_manifest "$op_id")"
  [[ -f "$man" ]] || { printf '{"rollback_available":false}\n'; return 0; }
  hours="${SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS:-24}"
  SOVIEZ_M="$(cat "$man")" SOVIEZ_H="$hours" python3 - <<'PY'
import json,os
from datetime import datetime,timedelta,timezone
m=json.loads(os.environ["SOVIEZ_M"])
created=m.get("created_at") or ""
hours=int(os.environ["SOVIEZ_H"])
try:
  dt=datetime.fromisoformat(created.replace("Z","+00:00"))
except Exception:
  dt=datetime.now(timezone.utc)
expires=(dt+timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
  "rollback_available":True,
  "safety_window_hours":hours,
  "rollback_expires_at":expires,
  "previous_digest":m.get("previous_digest"),
  "cleanup_eligible_after":expires,
},separators=(",",":")))
PY
}
