# shellcheck shell=bash

soviez_migration_authorization_plan() {
  local pair_id="$1"
  local account_id="${SOVIEZ_MIG_P20_ACCOUNT_ID:-acct-p20}"
  local license_id="${SOVIEZ_MIG_P20_LICENSE_ID:-lic-p20}"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_AUTH_PLAN"
  soviez_migration_token_assert_canonical_only
  local reval elig plan_id
  if ! reval="$(soviez_migration_p20_revalidate_phase19 "$pair_id")"; then
    soviez_migration_die MIGRATION_PHASE19_READINESS_REQUIRED "Phase 19 revalidation failed"
  fi
  elig="$(soviez_migration_token_eligibility_p20 "$account_id" "$license_id")"
  local status
  status="$(soviez_json_get "$elig" status)"
  [[ "$status" == "eligible" ]] || soviez_migration_die MIGRATION_TOKEN_NOT_ELIGIBLE "token not eligible: $(soviez_json_get "$elig" code)"
  plan_id="$(soviez_migration_new_id aplan)"
  local dir
  dir="$(soviez_migration_p20_auth_dir "$plan_id")"
  mkdir -p "$dir"
  SOVIEZ_PLAN="$plan_id" SOVIEZ_OUT="$dir/plan.json" SOVIEZ_PAIR="$pair_id" SOVIEZ_REVAL="$reval" SOVIEZ_ELIG="$elig" \
    SOVIEZ_ACC="$account_id" SOVIEZ_LIC="$license_id" python3 - <<'PY'
import json,os,time
reval=json.loads(os.environ["SOVIEZ_REVAL"]); elig=json.loads(os.environ["SOVIEZ_ELIG"])
body={
 "schema":"soviez.migration_authorization_plan.v1",
 "plan_id":os.environ["SOVIEZ_PLAN"],
 "pair_id":os.environ["SOVIEZ_PAIR"],
 "account_id":os.environ["SOVIEZ_ACC"],
 "license_id":os.environ["SOVIEZ_LIC"],
 "phase19":reval,
 "token_eligibility":elig,
 "grant_id":elig.get("grant_id"),
 "phase21_allowed":False,
 "production_dns_changed":False,
 "traffic_cutover_started":False,
 "created_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body,separators=(",",":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}

soviez_migration_authorization_commit() {
  local pair_id="$1"
  local confirm="${2:-0}"
  [[ "$confirm" == "1" || "${SOVIEZ_CLI_YES:-0}" == "1" || "${SOVIEZ_MIG_ASSUME_YES:-0}" == "1" ]] || \
    soviez_migration_die MIGRATION_CONFIRMATION_REQUIRED "authorization commit requires confirm"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_AUTH_COMMIT"
  export SOVIEZ_MIG_P20_CANONICAL_COMMIT=1
  local account_id="${SOVIEZ_MIG_P20_ACCOUNT_ID:-acct-p20}"
  local license_id="${SOVIEZ_MIG_P20_LICENSE_ID:-lic-p20}"
  local op_id idem_key
  op_id="$(soviez_migration_new_id opauth)"
  idem_key="${SOVIEZ_MIG_P20_IDEMPOTENCY_KEY:-idem-$op_id}"
  local reval
  if ! reval="$(soviez_migration_p20_revalidate_phase19 "$pair_id")"; then
    soviez_migration_die MIGRATION_PHASE19_READINESS_REQUIRED "Phase 19 revalidation failed"
  fi
  local staging_id grant_id
  staging_id="$(soviez_json_get "$reval" staging_id)"
  local elig
  elig="$(soviez_migration_token_eligibility_p20 "$account_id" "$license_id")"
  grant_id="$(soviez_json_get "$elig" grant_id)"
  [[ -n "$grant_id" ]] || soviez_migration_die MIGRATION_TOKEN_REQUIRED "grant missing"

  local payload
  payload="$(SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_IDEM="$idem_key" SOVIEZ_ACC="$account_id" \
    SOVIEZ_LIC="$license_id" SOVIEZ_GRANT="$grant_id" SOVIEZ_STG="$staging_id" \
    SOVIEZ_SFP="${SOVIEZ_MIG_P20_SOURCE_FP:-fp-source}" SOVIEZ_DFP="${SOVIEZ_MIG_P20_DEST_FP:-fp-dest}" \
    SOVIEZ_SDB="${SOVIEZ_MIG_P20_SOURCE_DB:-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}" \
    SOVIEZ_DDB="${SOVIEZ_MIG_P20_DEST_DB:-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}" \
    SOVIEZ_SDG="${SOVIEZ_MIG_P20_SOURCE_DIGEST:-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}" \
    SOVIEZ_DDG="${SOVIEZ_MIG_P20_DEST_DIGEST:-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}" \
    SOVIEZ_STAGES="${SOVIEZ_MIG_P20_STAGE_IDS:-}" SOVIEZ_MAND="${SOVIEZ_MIG_P20_MANDATORY_STAGES:-}" \
    SOVIEZ_PROD="${SOVIEZ_MIG_P20_SOURCE_PROD:-prod-p20}" SOVIEZ_DEST_ENV="${SOVIEZ_MIG_P20_DEST_ENV:-dest-p20}" \
    SOVIEZ_READY="$(soviez_json_get "$reval" ready_for_20)" python3 - <<'PY'
import json,os,hashlib
stages=[s for s in os.environ.get("SOVIEZ_STAGES","").split(",") if s]
mand=[s for s in os.environ.get("SOVIEZ_MAND","").split(",") if s]
body={
 "account_id":os.environ["SOVIEZ_ACC"],
 "license_id":os.environ["SOVIEZ_LIC"],
 "pair_id":os.environ["SOVIEZ_PAIR"],
 "operation_id":os.environ["SOVIEZ_OP"],
 "idempotency_key":os.environ["SOVIEZ_IDEM"],
 "grant_id":os.environ["SOVIEZ_GRANT"],
 "staging_id":os.environ["SOVIEZ_STG"],
 "readiness_id":"ready-"+os.environ["SOVIEZ_PAIR"],
 "source_fp":os.environ["SOVIEZ_SFP"],
 "dest_fp":os.environ["SOVIEZ_DFP"],
 "source_db_uuid":os.environ["SOVIEZ_SDB"],
 "dest_db_uuid":os.environ["SOVIEZ_DDB"],
 "source_digest":os.environ["SOVIEZ_SDG"],
 "dest_digest":os.environ["SOVIEZ_DDG"],
 "source_production_id":os.environ["SOVIEZ_PROD"],
 "source_environment_id":os.environ["SOVIEZ_PROD"],
 "dest_environment_id":os.environ["SOVIEZ_DEST_ENV"],
 "stage_ids":stages,
 "mandatory_stage_ids":mand,
}
raw=json.dumps({k:v for k,v in body.items() if k!="request_hash"},separators=(",",":"),sort_keys=True)
body["request_hash"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(body,separators=(",",":")))
PY
)"

  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '%s\n' "{\"operation_id\":\"$op_id\",\"operation_type\":\"migration_authorization_commit\",\"current_state\":\"committing_token_and_binding\",\"migration_pair_id\":\"$pair_id\"}" \
    > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"

  local receipt
  set +e
  receipt="$(soviez_migration_p20_ledger commit --payload-json "$payload" 2>/tmp/p20-commit.err)"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    local code
    code="$(python3 -c 'import json,sys; print(json.load(open("/tmp/p20-commit.err")).get("code","MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN"))' 2>/dev/null || echo MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN)"
    printf '%s\n' "{\"operation_id\":\"$op_id\",\"current_state\":\"failed_precommit\",\"code\":\"$code\"}" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
    soviez_migration_die "$code" "authorization commit failed"
  fi

  local auth_id
  auth_id="$(soviez_json_get "$receipt" authorization_id)"
  mkdir -p "$(soviez_migration_p20_auth_dir "$auth_id")"
  printf '%s\n' "$receipt" > "$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  printf '%s\n' "$receipt" > "$SOVIEZ_MIG_ROOT/ops/$op_id/authorization.json"
  printf '%s\n' "{\"operation_id\":\"$op_id\",\"operation_type\":\"migration_authorization_commit\",\"current_state\":\"authorization_committed\",\"authorization_id\":\"$auth_id\",\"migration_pair_id\":\"$pair_id\",\"migration_token_consumed\":true,\"destination_production_activated\":false,\"traffic_cutover_started\":false,\"production_dns_changed\":false}" \
    > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  printf '%s\n' "$receipt"
}

soviez_migration_authorization_show() {
  local auth_id="$1"
  local f
  f="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization not found"
  cat "$f"
}

soviez_migration_authorization_recover() {
  local op_id="$1"
  local sf="$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  [[ -f "$sf" ]] || soviez_migration_die MIGRATION_NOT_FOUND "op missing"
  if [[ -f "$SOVIEZ_MIG_ROOT/ops/$op_id/authorization.json" ]]; then
    cat "$SOVIEZ_MIG_ROOT/ops/$op_id/authorization.json"
    return 0
  fi
  local idem="${SOVIEZ_MIG_P20_IDEMPOTENCY_KEY:-}"
  local acc="${SOVIEZ_MIG_P20_ACCOUNT_ID:-acct-p20}"
  [[ -n "$idem" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN "idempotency key required for recover"
  soviez_migration_p20_ledger get --account-id "$acc" --idempotency-key "$idem"
}
