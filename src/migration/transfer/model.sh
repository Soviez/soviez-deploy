# shellcheck shell=bash

soviez_migration_transfer_op_state_path() {
  local op_id="$1"
  printf '%s/state.json\n' "$(soviez_migration_transfer_op_dir "$op_id")"
}

soviez_migration_transfer_state_write() {
  local op_id="$1" json="$2"
  local dir
  soviez_migration_paths_init
  dir="$(soviez_migration_transfer_op_dir "$op_id")"
  mkdir -p "$dir"
  soviez_migration_write_json "$dir/state.json" "$json"
}

soviez_migration_transfer_state_read() {
  local op_id="$1"
  local path
  path="$(soviez_migration_transfer_op_state_path "$op_id")"
  [[ -f "$path" ]] || return 1
  cat "$path"
}

soviez_migration_transfer_state_merge() {
  local op_id="$1" patch="$2"
  local path cur
  path="$(soviez_migration_transfer_op_state_path "$op_id")"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]]; then
    cur="$(cat "$path")"
  else
    cur="{}"
  fi
  SOVIEZ_C="$cur" SOVIEZ_P="$patch" SOVIEZ_PATH="$path" python3 - <<'PY'
import json, os
c=json.loads(os.environ["SOVIEZ_C"] or "{}")
p=json.loads(os.environ["SOVIEZ_P"])
c.update(p)
# Phase 19 invariants — never allow Phase 20 mutations via state merge
c["migration_token_reserved"]=False
c["migration_token_consumed"]=False
c["destination_production_activated"]=False
c["traffic_cutover_started"]=False
open(os.environ["SOVIEZ_PATH"],"w").write(json.dumps(c, separators=(",", ":")))
print(json.dumps(c, separators=(",", ":")))
PY
}

soviez_migration_transfer_default_flags_json() {
  printf '%s\n' '{"migration_token_reserved":false,"migration_token_consumed":false,"destination_production_activated":false,"traffic_cutover_started":false,"source_license_active":true,"source_runtime_active":true}'
}
