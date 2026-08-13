# shellcheck shell=bash

soviez_migration_config_secret_inventory() {
  local inventory_json="$1" out_path="$2"
  mkdir -p "$(dirname "$out_path")"
  SOVIEZ_I="$inventory_json" SOVIEZ_O="$out_path" python3 - <<'PY'
import json, os, datetime
inv=json.loads(os.environ["SOVIEZ_I"])
secrets=list(inv.get("secrets_detected") or [])
doc={
  "schema_version":"soviez.migration_secret_inventory.v1",
  "secrets":[{"key":k,"transfer_authorized":False,"remediation":"re-enter_at_destination"} for k in secrets],
  "automatic_secret_transfer": False,
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.environ["SOVIEZ_O"],"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY
}
