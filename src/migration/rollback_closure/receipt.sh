# shellcheck shell=bash

soviez_migration_rollback_window_write_receipt() {
  local op_id="$1" cutover_id="$2" auth_id="$3"
  local out_dir receipt byc wf
  out_dir="$(soviez_migration_p22_closure_dir "$op_id")"
  mkdir -p "$out_dir" "$(dirname "$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")")"
  receipt="$out_dir/receipt.json"

  # Mark DNS snapshot as manual_recovery_only if present.
  wf="$(soviez_migration_cutover_rollback_window_path "$cutover_id")"
  if [[ -f "$wf" ]]; then
    SOVIEZ_WF="$wf" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_WF"]
d=json.load(open(p))
d["manual_recovery_only"]=True
d["automatic_rollback_allowed"]=False
d["window_closed"]=True
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  fi

  # Also stamp DNS zone snapshot marker if exists.
  local dns_snap
  dns_snap="$(soviez_migration_cutover_op_dir "$cutover_id")/dns_rollback_snapshot.json"
  if [[ -f "$dns_snap" ]]; then
    SOVIEZ_D="$dns_snap" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_D"]
d=json.load(open(p))
d["manual_recovery_only"]=True
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  else
    printf '{"manual_recovery_only":true,"retained":true}\n' > "$dns_snap"
  fi

  SOVIEZ_OUT="$receipt" SOVIEZ_OP="$op_id" SOVIEZ_CID="$cutover_id" SOVIEZ_AID="$auth_id" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_rollback_window_close.v1",
  "operation_id":os.environ["SOVIEZ_OP"],
  "operation_type":"migration_rollback_window_close",
  "cutover_id":os.environ["SOVIEZ_CID"],
  "authorization_id":os.environ["SOVIEZ_AID"],
  "status":"closed",
  "automatic_rollback_allowed":False,
  "manual_recovery_only":True,
  "data_deleted":False,
  "runtime_stopped":False,
  "closed_at":os.environ["SOVIEZ_NOW"],
  "signer":"soviez-p22",
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$receipt"
  cp -f "$receipt" "$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
  cat "$receipt"
}
