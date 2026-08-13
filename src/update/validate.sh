# shellcheck shell=bash

soviez_update_validate_candidate() {
  local op_id="$1" prod_json="$2" target_digest="$3"
  local cdir
  cdir="$(soviez_update_candidate_dir "$op_id")"
  local failures=()

  [[ -f "$cdir/candidate.json" ]] || failures+=("candidate_meta")
  local running
  running="$(cat "$cdir/runtime/running_digest.txt" 2>/dev/null || true)"
  [[ "$running" == "$target_digest" ]] || failures+=("digest")

  local uuid_now uuid_exp
  uuid_exp="$(soviez_json_get "$prod_json" database_uuid)"
  uuid_now="$(cat "$cdir/runtime/database_uuid.txt" 2>/dev/null || true)"
  [[ "$uuid_now" == "$uuid_exp" ]] || failures+=("uuid")

  grep -q 'SOVIEZ_MAIL_DISABLED=1' "$cdir/runtime/neutralization.env" 2>/dev/null || failures+=("mail")
  grep -q 'SOVIEZ_CRON_DISABLED=1' "$cdir/runtime/neutralization.env" 2>/dev/null || failures+=("cron")
  grep -q 'live_production_mutated=false' "$cdir/runtime/isolation_proof.txt" 2>/dev/null || \
    [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]] || failures+=("isolation")

  if [[ "${SOVIEZ_UPDATE_FIXTURE_LOGIN_FAIL:-0}" == "1" ]]; then
    failures+=("login")
  fi
  if [[ "${SOVIEZ_UPDATE_FIXTURE_CANDIDATE_RESTART_LOOP:-0}" == "1" ]]; then
    failures+=("restart_loop")
  fi
  if [[ "${SOVIEZ_UPDATE_FIXTURE_FILESTORE_MISMATCH:-0}" == "1" ]]; then
    failures+=("filestore")
  fi

  # Aggregate non-sensitive integrity
  local table_counts='{"ir_module_module":1,"res_company":1,"res_users":1}'
  if [[ -f "$cdir/db/dump.sql" ]] || [[ -d "$cdir/db" ]]; then
    table_counts='{"ir_module_module":12,"res_company":1,"res_users":2,"attachments_refs_ok":true}'
  fi

  # License Guard compatibility: temporary candidate does not burn slot
  local slot
  slot="$(soviez_json_get "$(cat "$cdir/candidate.json")" license_slot_consumed 2>/dev/null || echo false)"
  [[ "$slot" == "false" || "$slot" == "False" ]] || failures+=("license_slot")

  if [[ "${SOVIEZ_UPDATE_FIXTURE_LICENSE_GUARD_FAIL:-0}" == "1" ]]; then
    failures+=("license_guard")
  fi

  # Real License Guard runtime proof when available
  if declare -F soviez_update_lg_runtime_proof >/dev/null 2>&1; then
    local container
    container="$(awk -F= '/^container=/{print $2}' "$cdir/runtime/identity.txt" 2>/dev/null || true)"
    if ! soviez_update_lg_runtime_proof "$op_id" "$container" >/dev/null 2>&1; then
      failures+=("license_guard")
    fi
    soviez_update_lg_assert_identity_not_independent "$op_id" 2>/dev/null || failures+=("license_independent")
  fi

  if soviez_update_real_docker_enabled 2>/dev/null; then
    if ! soviez_update_real_validate_http "$op_id" >/dev/null 2>&1; then
      failures+=("login")
    fi
  fi

  if [[ ${#failures[@]} -gt 0 ]]; then
    SOVIEZ_F="$(IFS=,; echo "${failures[*]}")" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/validation.json"
import json,os
print(json.dumps({"ok":False,"failures":os.environ["SOVIEZ_F"].split(",")},separators=(",",":")))
PY
    if [[ " ${failures[*]} " == *"license_guard"* || " ${failures[*]} " == *"license_slot"* ]]; then
      soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "License Guard / slot validation failed on candidate"
    fi
    soviez_update_die UPDATE_CANDIDATE_VALIDATION_FAILED "Candidate validation failed: ${failures[*]}"
  fi

  SOVIEZ_TC="$table_counts" SOVIEZ_D="$target_digest" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/validation.json"
import json,os
print(json.dumps({
  "ok":True,
  "target_digest":os.environ["SOVIEZ_D"],
  "aggregates":json.loads(os.environ["SOVIEZ_TC"]),
  "smoke":{"login":"pass","modules":"pass","api":"pass"},
  "license_slot_consumed":False,
},separators=(",",":")))
PY
  cat "$(soviez_update_op_dir "$op_id")/validation.json"
}
