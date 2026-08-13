# shellcheck shell=bash

soviez_migration_addons_transfer() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local inv out_dir
  out_dir="$(soviez_migration_transfer_op_dir "$op_id")/addons"
  mkdir -p "$out_dir"
  inv="$(soviez_migration_addons_inventory "$pair_id")"
  SOVIEZ_I="$inv" SOVIEZ_OUT="$out_dir/inventory.json" python3 - <<'PY'
import json, os
inv=json.loads(os.environ["SOVIEZ_I"])
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(inv, separators=(",", ":")))
print(json.dumps({"status":"inventory_recorded","count": len(inv.get("addons") or [])}, separators=(",", ":")))
PY
  # Resolve registry digests for each addon
  SOVIEZ_I="$inv" python3 -c 'import json,os; [print(a.get("name",""), a.get("version",""), sep="\t") for a in json.loads(os.environ["SOVIEZ_I"]).get("addons") or []]' \
  | while IFS=$'\t' read -r name ver; do
      [[ -n "$name" ]] || continue
      soviez_migration_addons_registry_resolve "$name" "$ver" > "$out_dir/${name}.resolved.json"
    done
  printf '{"status":"addons_presync_complete","operation_id":"%s"}\n' "$op_id"
}
