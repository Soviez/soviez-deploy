# shellcheck shell=bash

soviez_migration_staging_capacity_check() {
  local pair_id="$1" staging_id="$2"
  local margin="${SOVIEZ_MIG_CAPACITY_MARGIN_PCT:-25}"
  # Fixture: always PASS unless SOVIEZ_MIG_FIXTURE_CAPACITY_BLOCK=1
  if [[ "${SOVIEZ_MIG_FIXTURE_CAPACITY_BLOCK:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_CAPACITY_BLOCKED "Destination capacity insufficient"
  fi
  SOVIEZ_M="$margin" SOVIEZ_S="$staging_id" python3 - <<'PY'
import json, os, shutil
margin=int(os.environ["SOVIEZ_M"])
usage=shutil.disk_usage("/")
required=1024*1024  # minimal fixture requirement
required_with_margin=int(required*(100+margin)/100)
print(json.dumps({
  "staging_id": os.environ["SOVIEZ_S"],
  "required_bytes": required_with_margin,
  "available_bytes": usage.free,
  "margin_pct": margin,
  "result": "PASS" if usage.free >= required_with_margin else "BLOCKED",
}, separators=(",", ":")))
PY
}
