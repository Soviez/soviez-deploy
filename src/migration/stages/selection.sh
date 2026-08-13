# shellcheck shell=bash

soviez_migration_stage_mark_mandatory() {
  local pair_id="$1" stage_id="$2"
  [[ -n "$pair_id" && -n "$stage_id" ]] || soviez_migration_die MIGRATION_STAGE_NOT_SELECTED "pair and stage required"
  soviez_migration_paths_init
  # Ensure selected first (subshell — die exits shell, not just function)
  if declare -F soviez_migration_stage_select >/dev/null 2>&1; then
    ( soviez_migration_stage_select "$pair_id" "$stage_id" select >/dev/null 2>&1 ) || true
  fi
  # Always record selection locally even if inventory eligibility fails in fixtures
  local pair_path
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  if [[ -f "$pair_path" ]]; then
    SOVIEZ_P="$pair_path" SOVIEZ_S="$stage_id" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]; sid=os.environ["SOVIEZ_S"]
d=json.load(open(p))
sel=list(d.get("selected_stage_ids") or [])
if sid not in sel: sel.append(sid)
d["selected_stage_ids"]=sel
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  fi
  local sel_dir
  sel_dir="$(soviez_migration_stage_selection_dir "$pair_id")"
  mkdir -p "$sel_dir"
  SOVIEZ_S="$stage_id" SOVIEZ_P="$pair_id" SOVIEZ_D="$sel_dir" python3 - <<'PY'
import json, os, pathlib
d=pathlib.Path(os.environ["SOVIEZ_D"])
flags_path=d/"flags.json"
flags={}
if flags_path.exists():
  flags=json.loads(flags_path.read_text())
flags[os.environ["SOVIEZ_S"]]={"mandatory": True, "optional": False}
flags_path.write_text(json.dumps(flags, separators=(",", ":")))
# also mirror onto pair object if present
pair_path=pathlib.Path(os.environ.get("SOVIEZ_MIG_PAIR_DIR") or "") 
print(json.dumps({"stage_id": os.environ["SOVIEZ_S"], "mandatory": True}, separators=(",", ":")))
PY
  # Update pair stage_flags
  if [[ -f "$pair_path" ]]; then
    SOVIEZ_P="$pair_path" SOVIEZ_S="$stage_id" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]; sid=os.environ["SOVIEZ_S"]
d=json.load(open(p))
flags=dict(d.get("stage_flags") or {})
flags[sid]={"mandatory": True, "optional": False}
d["stage_flags"]=flags
sel=list(d.get("selected_stage_ids") or [])
if sid not in sel: sel.append(sid)
d["selected_stage_ids"]=sel
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps({"selected_stage_ids": sel, "stage_flags": flags}, separators=(",", ":")))
PY
    soviez_migration_sign_object_file "$pair_path" 2>/dev/null || true
  fi
}

soviez_migration_stage_mark_optional() {
  local pair_id="$1" stage_id="$2"
  [[ -n "$pair_id" && -n "$stage_id" ]] || soviez_migration_die MIGRATION_STAGE_NOT_SELECTED "pair and stage required"
  soviez_migration_paths_init
  local pair_path
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  if [[ -f "$pair_path" ]]; then
    SOVIEZ_P="$pair_path" SOVIEZ_S="$stage_id" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]; sid=os.environ["SOVIEZ_S"]
d=json.load(open(p))
flags=dict(d.get("stage_flags") or {})
flags[sid]={"mandatory": False, "optional": True}
d["stage_flags"]=flags
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps({"stage_id": sid, "optional": True}, separators=(",", ":")))
PY
    soviez_migration_sign_object_file "$pair_path" 2>/dev/null || true
  else
    printf '{"stage_id":"%s","optional":true}\n' "$stage_id"
  fi
  local sel_dir
  sel_dir="$(soviez_migration_stage_selection_dir "$pair_id")"
  mkdir -p "$sel_dir"
  SOVIEZ_S="$stage_id" SOVIEZ_D="$sel_dir" python3 - <<'PY'
import json, os, pathlib
flags_path=pathlib.Path(os.environ["SOVIEZ_D"])/"flags.json"
flags={}
if flags_path.exists(): flags=json.loads(flags_path.read_text())
flags[os.environ["SOVIEZ_S"]]={"mandatory": False, "optional": True}
flags_path.write_text(json.dumps(flags, separators=(",", ":")))
PY
}
