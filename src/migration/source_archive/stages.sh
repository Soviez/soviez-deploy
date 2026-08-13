# shellcheck shell=bash

soviez_migration_p22_archive_stages() {
  local op_id="$1"
  local out status=ok
  out="$(soviez_migration_p22_archive_op_dir "$op_id")/stages.json"
  mkdir -p "$(dirname "$out")"
  # Metadata only — never delete Stage resources.
  if [[ "${SOVIEZ_MIG_P22_STAGE_MANDATORY_FAIL:-0}" == "1" ]]; then
    status=BLOCKED
  elif [[ "${SOVIEZ_MIG_P22_STAGE_OPTIONAL_FAIL:-0}" == "1" ]]; then
    status=WARNING
  fi
  SOVIEZ_OUT="$out" SOVIEZ_ST="$status" python3 - <<'PY'
import json, os
st=os.environ["SOVIEZ_ST"]
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps({
  "stages_metadata_archived": True,
  "stages_deleted": False,
  "status": st,
  "optional_fail_warning": st=="WARNING",
  "mandatory_fail_blocked": st=="BLOCKED",
}, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
  if [[ "$status" == "BLOCKED" ]]; then
    soviez_migration_die MIGRATION_STAGE_SOURCE_ARCHIVE_FAILED "mandatory stage archive metadata failed"
  fi
}
