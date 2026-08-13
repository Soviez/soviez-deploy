# shellcheck shell=bash

soviez_migration_transfer_resume_from_registry() {
  local op_id="$1" profile="${2:-balanced}"
  local reg state
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  [[ -f "$reg" ]] || soviez_migration_die MIGRATION_RESUME_REQUIRED "Chunk registry missing for $op_id"
  # Re-transfer only non-verified chunks
  SOVIEZ_REG="$reg" python3 -c '
import json,os
d=json.load(open(os.environ["SOVIEZ_REG"]))
for cid,c in d.get("chunks",{}).items():
  st=c.get("state")
  if st not in ("verified","assembled"):
    print(cid)
' | while read -r chunk_id; do
    [[ -n "$chunk_id" ]] || continue
    path="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" python3 -c 'import json,os; print(json.load(open(os.environ["SOVIEZ_REG"]))["chunks"][os.environ["SOVIEZ_CID"]]["local_path"])')"
    [[ -f "$path" ]] || soviez_migration_die MIGRATION_TRANSFER_RESUME_MISMATCH "Missing chunk payload on resume: $chunk_id"
    soviez_migration_channel_put "$op_id" "$chunk_id" "$path" >/dev/null
    soviez_migration_chunk_verify "$op_id" "$chunk_id" >/dev/null
    soviez_migration_bandwidth_profile_delay "$profile"
  done
  soviez_migration_transfer_state_merge "$op_id" '{"current_state":"resumed","checkpoint":"chunks_verified"}' >/dev/null
  printf '{"operation_id":"%s","status":"resumed"}\n' "$op_id"
}
