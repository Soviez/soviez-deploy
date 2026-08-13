# shellcheck shell=bash

soviez_migration_stage_eligibility_check() {
  local pair_id="$1" stage_id="$2"
  local pair discovery_id discovery
  pair="$(soviez_migration_transfer_load_pair "$pair_id")"
  discovery_id="$(soviez_json_get "$pair" source_discovery_id)"
  [[ -n "$discovery_id" && "$discovery_id" != "null" ]] || \
    soviez_migration_die MIGRATION_STAGE_NOT_ELIGIBLE "No discovery for stage eligibility"
  discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json")"
  SOVIEZ_D="$discovery" SOVIEZ_S="$stage_id" SOVIEZ_PAIR="$pair" python3 - <<'PY'
import json, os, sys
disc=json.loads(os.environ["SOVIEZ_D"])
sid=os.environ["SOVIEZ_S"]
pair=json.loads(os.environ["SOVIEZ_PAIR"])
stages=(disc.get("stages") or {}).get("stages") or []
match=[s for s in stages if s.get("stage_id")==sid]
if not match:
  print("MISSING"); sys.exit(31)
st=match[0]
if not st.get("selectable", False):
  print("NOT_SELECTABLE"); sys.exit(32)
if st.get("expired") or st.get("retention_ended"):
  print("EXPIRED"); sys.exit(32)
parent=st.get("parent_production_id") or st.get("production_id") or ""
src=pair.get("source_production_id") or pair.get("production_id") or ""
if parent and src and parent!=src:
  print("WRONG_PARENT"); sys.exit(33)
print(json.dumps({"stage_id": sid, "eligible": True}, separators=(",", ":")))
PY
  local rc=$?
  case $rc in
    31) soviez_migration_die MIGRATION_STAGE_NOT_ELIGIBLE "Unknown stage" ;;
    32) soviez_migration_die MIGRATION_STAGE_EXPIRED "Stage not eligible" ;;
    33) soviez_migration_die MIGRATION_STAGE_NOT_ELIGIBLE "Wrong parent production" ;;
  esac
}
