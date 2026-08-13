# shellcheck shell=bash

soviez_migration_p22_archive_secret_inventory() {
  local op_id="$1"
  local out
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/secret_inventory.json"
  mkdir -p "$(dirname "$out")"
  # Inventory only — never store secret values.
  SOVIEZ_OUT="$out" python3 - <<'PY'
import json, os
items=[]
for name in ("SOVIEZ_MIG_P22_SOURCE_DB_PASSWORD","SOVIEZ_BACKUP_PASSPHRASE","SOVIEZ_MIG_PG_PASSWORD"):
  present = bool(os.environ.get(name))
  items.append({"name": name, "present": present, "value_recorded": False})
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "secrets": items,
  "disposition_required": True,
  "values_stored": False,
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}
