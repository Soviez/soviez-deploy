# shellcheck shell=bash

soviez_migration_config_sanitize() {
  local inventory_json="$1"
  SOVIEZ_I="$inventory_json" python3 - <<'PY'
import json, os, re
inv=json.loads(os.environ["SOVIEZ_I"])
settings=dict(inv.get("settings") or {})
deny_keys=re.compile(r"(password|secret|token|api[_-]?key|private[_-]?key|credential|smtp\.|webhook|stripe|dns\.|registry\.auth)", re.I)
clean={}
removed=[]
for k,v in settings.items():
  if deny_keys.search(k):
    removed.append(k); continue
  if isinstance(v,str) and deny_keys.search(v):
    removed.append(k); continue
  clean[k]=v
# Neutralize integrations
clean["mail.enabled"]=False
clean["cron.enabled"]=False
clean["payment.enabled"]=False
clean["webhook.enabled"]=False
print(json.dumps({"settings": clean, "removed_secret_keys": removed, "neutralized": True}, separators=(",", ":")))
PY
}
