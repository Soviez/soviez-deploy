# shellcheck shell=bash

soviez_migration_p22_retirement_inventory() {
  local source_id="$1"
  local out_dir out
  out_dir="$(soviez_migration_p22_retirement_dir "$source_id")"
  mkdir -p "$out_dir"
  out="$out_dir/inventory.json"
  local unknown=0
  [[ "${SOVIEZ_MIG_P22_UNKNOWN_RESOURCES:-0}" == "1" ]] && unknown=1
  SOVIEZ_OUT="$out" SOVIEZ_SID="$source_id" SOVIEZ_UNK="$unknown" python3 - <<'PY'
import json, os
unk=os.environ["SOVIEZ_UNK"]=="1"
resources=[
  {"kind":"host","id":"source-host","known":True,"retained":True},
  {"kind":"volume","id":"source-data","known":True,"retained":True},
  {"kind":"backup","id":"pinned","known":True,"retained":True},
]
if unk:
  resources.append({"kind":"unknown","id":"mystery","known":False,"retained":True})
body={
  "source_id": os.environ["SOVIEZ_SID"],
  "resources": resources,
  "unknown_count": 1 if unk else 0,
  "purge_authorized": False,
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
