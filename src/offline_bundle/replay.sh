# shellcheck shell=bash
# Local replay registry — inspect/import repeatable; successful apply once.

soviez_offline_replay_get() {
  local bundle_id="$1"
  soviez_offline_bundle_paths_init
  SOVIEZ_DB="$SOVIEZ_OFFLINE_BUNDLE_REPLAY_DB" SOVIEZ_ID="$bundle_id" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_DB"]))
e=d.get("entries",{}).get(os.environ["SOVIEZ_ID"])
print(json.dumps(e) if e else "")
PY
}

soviez_offline_replay_upsert() {
  local bundle_id="$1"
  shift
  soviez_offline_bundle_paths_init
  SOVIEZ_DB="$SOVIEZ_OFFLINE_BUNDLE_REPLAY_DB" SOVIEZ_ID="$bundle_id" python3 - "$@" <<'PY'
import json, os, sys, datetime
kv={}
for a in sys.argv[1:]:
  if "=" in a:
    k,v=a.split("=",1); kv[k]=v
p=os.environ["SOVIEZ_DB"]
d=json.load(open(p))
bid=os.environ["SOVIEZ_ID"]
e=d.setdefault("entries",{}).setdefault(bid,{})
now=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
if "first_imported_at" not in e and kv.get("mark_imported")=="1":
  e["first_imported_at"]=now
if kv.get("mark_inspected")=="1":
  e["last_inspected_at"]=now
for k,v in kv.items():
  if k.startswith("mark_"):
    continue
  if k=="successful_apply_count":
    e[k]=int(v)
  else:
    e[k]=v
e["bundle_id"]=bid
open(p,"w").write(json.dumps(d, indent=2, sort_keys=True)+"\n")
print(json.dumps(e, separators=(",",":")))
PY
}

soviez_offline_replay_assert_apply_allowed() {
  local bundle_id="$1" env_id="$2" device_fp="$3"
  local entry count state
  entry="$(soviez_offline_replay_get "$bundle_id")"
  [[ -n "$entry" ]] || return 0
  count="$(soviez_json_get "$entry" successful_apply_count 2>/dev/null || echo 0)"
  state="$(soviez_json_get "$entry" apply_state 2>/dev/null || true)"
  if [[ "${count:-0}" -ge 1 || "$state" == "applied_success" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_ALREADY_APPLIED "Bundle already applied successfully"
  fi
  local e_env e_dev
  e_env="$(soviez_json_get "$entry" environment_id 2>/dev/null || true)"
  e_dev="$(soviez_json_get "$entry" device_fingerprint 2>/dev/null || true)"
  if [[ -n "$e_env" && "$e_env" != "$env_id" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_REPLAY_DENIED "Replay environment mismatch"
  fi
  if [[ -n "$e_dev" && "$e_dev" != "$device_fp" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_REPLAY_DENIED "Replay device mismatch"
  fi
  return 0
}
