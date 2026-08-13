# shellcheck shell=bash

soviez_migration_p22_retirement_readiness() {
  local source_id="$1"
  local blockers=()
  set +e
  soviez_migration_p22_retirement_inventory_check "$source_id" >/dev/null 2>&1 || blockers+=("unknown_resources")
  soviez_migration_p22_retirement_suspend_check "$source_id" >/dev/null 2>&1 || blockers+=("not_suspended")
  set -e
  local status=PASS
  [[ ${#blockers[@]} -eq 0 ]] || status=BLOCKED
  SOVIEZ_ST="$status" SOVIEZ_BL="$(printf '%s,' ${blockers[@]+"${blockers[@]}"})" SOVIEZ_SID="$source_id" python3 - <<'PY'
import json, os
bl=[x for x in os.environ.get("SOVIEZ_BL","").split(",") if x]
print(json.dumps({
  "source_id": os.environ["SOVIEZ_SID"],
  "readiness_status": os.environ["SOVIEZ_ST"],
  "blockers": bl,
  "purge_authorized": False,
}, separators=(",", ":")))
PY
}
