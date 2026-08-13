# shellcheck shell=bash

soviez_ops_schema_version() { printf '1\n'; }
soviez_ops_engine_version() { printf '0.15.0-phase15\n'; }
soviez_ops_now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

soviez_ops_new_record() {
  local op_id="$1" op_type="$2" environment_id="${3:-}" checkpoint="${4:-created}" meta="${5:-{}}"
  SOVIEZ_OP_ID="$op_id" SOVIEZ_OP_TYPE="$op_type" SOVIEZ_ENV_ID="$environment_id" \
    SOVIEZ_CHECKPOINT="$checkpoint" SOVIEZ_META="$meta" \
    SOVIEZ_HOST="$(hostname -f 2>/dev/null || hostname || echo unknown)" \
    python3 - <<'PY'
import json, os, time
try: meta=json.loads(os.environ["SOVIEZ_META"])
except json.JSONDecodeError: meta={}
now=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
rec={
 "schema_version":1,"engine_version":"0.15.0-phase15","adapter_version":"1",
 "operation_id":os.environ["SOVIEZ_OP_ID"],"operation_type":os.environ["SOVIEZ_OP_TYPE"],
 "command":os.environ["SOVIEZ_OP_TYPE"],"requested_action":os.environ["SOVIEZ_OP_TYPE"],
 "environment_id":os.environ["SOVIEZ_ENV_ID"] or None,"environment_type":None,
 "parent_production_id":None,"license_id":None,"resource_scope":[],
 "host_identity":os.environ.get("SOVIEZ_HOST") or "unknown","request_source":"local",
 "created_at":now,"queued_at":None,"started_at":None,"updated_at":now,"heartbeat_at":None,
 "completed_at":None,"canceled_at":None,"failed_at":None,"next_retry_at":None,
 "current_state":"created","previous_state":None,"state_entered_at":now,
 "current_checkpoint":os.environ["SOVIEZ_CHECKPOINT"],"progress_percent":0,
 "progress_message":None,"terminal":False,"success":None,
 "controller_pid":None,"worker_pid":None,"worker_identity":None,"systemd_unit":None,
 "systemd_invocation_id":None,"worker_started_at":None,"worker_generation":0,
 "lock_ids":[],"lock_owner":None,"lock_acquired_at":None,"lock_lease_until":None,"lock_generation":0,
 "retry_count":0,"retry_policy":"default","retryable":True,"last_retry_at":None,
 "cancel_requested":False,"cancel_requested_at":None,"cancel_requested_by":None,
 "cancel_reason":None,"cancellation_boundary":None,"cancel_safe":True,
 "rollback_available":False,"rollback_state":None,"rollback_checkpoint":None,
 "recovery_required":False,"recovery_reason":None,"recovery_checkpoint":None,
 "failure_code":None,"failure_class":None,"failure_message_safe":None,
 "failure_step":None,"failure_retryable":None,
 "state_path":None,"events_path":None,"log_path":None,"artifact_paths":[],"evidence_refs":[],
 "migrated_from_schema":None,"migration_timestamp":None,"sequence":0,"meta":meta,
 "canonical_sync_status":"synchronized","canonical_sync_revision":0,"canonical_synced_at":now,
 "canonical_sync_error_code":None,"canonical_sync_retry_count":0,
 "legacy_state_revision":0,"canonical_state_revision":0,"last_synchronized_transition":None,
 "registry_revision":0,"event_sequence":0,"terminal_cleanup_status":None
}
print(json.dumps(rec, separators=(",",":")))
PY
}

soviez_ops_forbid_secrets_in_json() {
  SOVIEZ_OPS_JSON="$1" python3 - <<'PY'
import json, os, re, sys
try: value=json.loads(os.environ["SOVIEZ_OPS_JSON"])
except Exception: raise SystemExit(2)
def walk(v):
  if isinstance(v, dict):
    for k, child in v.items():
      if re.search(r"password|private_key|token|secret|activation|credential|authorization", k, re.I): return False
      if not walk(child): return False
  elif isinstance(v, list):
    return all(walk(x) for x in v)
  elif isinstance(v, str):
    if re.search(r"BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|postgres(ql)?://[^:]+:[^@]+@", v, re.I): return False
  return True
raise SystemExit(0 if walk(value) else 1)
PY
}

soviez_ops_validate_record() {
  local json="$1"
  soviez_ops_forbid_secrets_in_json "$json" || soviez_ops_die OPERATION_STATE_CORRUPT "Canonical record contains secrets"
  SOVIEZ_OPS_JSON="$json" python3 - <<'PY'
import json, os, sys
try: d=json.loads(os.environ["SOVIEZ_OPS_JSON"])
except Exception: raise SystemExit(2)
if d.get("schema_version") != 1: raise SystemExit(3)
if not all(isinstance(d.get(k), str) and d[k] for k in ("operation_id","operation_type","current_state")): raise SystemExit(4)
PY
  case "$?" in
    0) ;;
    3) soviez_ops_die OPERATION_SCHEMA_UNSUPPORTED "Unsupported operation schema" ;;
    *) soviez_ops_die OPERATION_STATE_CORRUPT "Invalid canonical operation record" ;;
  esac
}
