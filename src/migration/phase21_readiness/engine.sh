# shellcheck shell=bash

soviez_migration_phase21_readiness() {
  local op_or_auth="$1"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_P21_READINESS"
  local auth_id="$op_or_auth"
  if [[ -f "$SOVIEZ_MIG_ROOT/ops/$op_or_auth/authorization.json" ]]; then
    auth_id="$(soviez_json_get "$(cat "$SOVIEZ_MIG_ROOT/ops/$op_or_auth/authorization.json")" authorization_id)"
  fi
  local authf actf gracef bakf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  actf="$SOVIEZ_MIG_ROOT/activation/$auth_id/activation.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization missing"
  local license_id
  license_id="$(soviez_json_get "$(cat "$authf")" license_id)"
  gracef="$SOVIEZ_MIG_ROOT/grace/$license_id/grace.json"
  bakf="$SOVIEZ_MIG_ROOT/activation/$auth_id/backup/backup.json"
  local blockers=() warnings=()
  [[ -f "$actf" ]] || blockers+=("destination_activation_missing")
  [[ -f "$gracef" ]] || blockers+=("source_grace_missing")
  [[ -f "$bakf" ]] || blockers+=("destination_backup_missing")
  local snap
  snap="$(soviez_migration_p20_ledger snapshot --license-id "$license_id")"
  local rem slots
  rem="$(soviez_json_get "$snap" grant_remaining)"
  slots="$(soviez_json_get "$snap" slot_count)"
  [[ "$rem" == "0" ]] || blockers+=("token_not_fully_consumed")
  [[ "$slots" == "1" ]] || blockers+=("slot_count_invalid")
  if [[ -f "$actf" ]]; then
    local pub
    pub="$(soviez_json_get "$(cat "$actf")" public_route)"
    [[ "$pub" == "false" || "$pub" == "False" ]] || blockers+=("public_route")
    local stg
    stg="$(soviez_json_get "$(cat "$actf")" stage_rebind)"
    [[ "$stg" != "BLOCKED" ]] || blockers+=("mandatory_stage_failure")
    [[ "$stg" != "WARNING" ]] || warnings+=("optional_stage_failure")
  fi
  if [[ "${SOVIEZ_MIG_P20_INJECT_DRIFT:-}" == "readiness" ]]; then
    blockers+=("drift")
  fi
  local report_id status
  report_id="$(soviez_migration_new_id p21r)"
  if [[ ${#blockers[@]} -gt 0 ]]; then status=BLOCKED
  elif [[ ${#warnings[@]} -gt 0 ]]; then status=WARNING
  else status=PASS
  fi
  mkdir -p "$SOVIEZ_MIG_ROOT/phase21_readiness/$report_id"
  SOVIEZ_OUT="$SOVIEZ_MIG_ROOT/phase21_readiness/$report_id/report.json" \
    SOVIEZ_RID="$report_id" SOVIEZ_AID="$auth_id" SOVIEZ_ST="$status" \
    SOVIEZ_BL="$(printf '%s,' ${blockers[@]+"${blockers[@]}"})" \
    SOVIEZ_WN="$(printf '%s,' ${warnings[@]+"${warnings[@]}"})" \
    SOVIEZ_SNAP="$snap" SOVIEZ_TTL="$SOVIEZ_MIG_P21_READINESS_TTL_SECONDS" python3 - <<'PY'
import json,os,time,hashlib
bl=[x for x in os.environ.get("SOVIEZ_BL","").split(",") if x]
wn=[x for x in os.environ.get("SOVIEZ_WN","").split(",") if x]
snap=json.loads(os.environ["SOVIEZ_SNAP"])
exp=time.time()+int(os.environ["SOVIEZ_TTL"])
body={
 "schema":"soviez.migration_phase21_readiness.v1",
 "report_id":os.environ["SOVIEZ_RID"],
 "authorization_id":os.environ["SOVIEZ_AID"],
 "readiness_status":os.environ["SOVIEZ_ST"],
 "token_consumed_count":1 if snap.get("grant_remaining")==0 else 0,
 "slot_count":snap.get("slot_count"),
 "traffic_owner":"source",
 "public_route":False,
 "production_dns_changed":False,
 "traffic_cutover_started":False,
 "phase21_allowed":False,
 "blockers":bl,
 "warnings":wn,
 "created_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
 "expires_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(exp)),
 "signer":"soviez-p20",
}
body["public_signature"]=hashlib.sha256(json.dumps(body,sort_keys=True,separators=(",",":")).encode()).hexdigest()
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body,separators=(",",":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}

soviez_migration_phase21_readiness_show() {
  local report_id="$1"
  local f="$SOVIEZ_MIG_ROOT/phase21_readiness/$report_id/report.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_PHASE21_NOT_READY "report missing"
  # expiry / drift
  SOVIEZ_F="$f" python3 - <<'PY'
import json,os,sys,time
from datetime import datetime
body=json.load(open(os.environ["SOVIEZ_F"]))
exp=body.get("expires_at")
# parse Z
try:
  t=datetime.strptime(exp,"%Y-%m-%dT%H:%M:%SZ").timestamp()
  if time.time()>t:
    print(json.dumps({"ok":False,"code":"MIGRATION_PHASE21_NOT_READY","message":"expired"},separators=(",",":")))
    sys.exit(25)
except Exception:
  pass
if os.environ.get("SOVIEZ_MIG_P20_INJECT_DRIFT")=="readiness":
  print(json.dumps({"ok":False,"code":"MIGRATION_PHASE19_DRIFT_DETECTED"},separators=(",",":")))
  sys.exit(25)
print(json.dumps(body,separators=(",",":")))
PY
}
