# shellcheck shell=bash

soviez_migration_p22_license_finalize() {
  local archive_op_id="$1"
  local out_dir statef ackf idem_key
  out_dir="$(soviez_migration_p22_finalization_dir "$archive_op_id")"
  mkdir -p "$out_dir"
  statef="$out_dir/license.json"
  ackf="$out_dir/license.ack"
  idem_key="p22-license-finalize:${archive_op_id}"

  # Enforce one license, one slot, token=1 (consumed), traffic_owner=destination.
  local st cutover_id auth_id to
  st="$(soviez_migration_source_archive_status "$archive_op_id")"
  [[ "$(soviez_json_get "$st" current_state)" == "verified" ]] || \
    soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "archive must be verified"
  cutover_id="$(soviez_json_get "$st" cutover_id)"
  auth_id="$(soviez_json_get "$st" authorization_id)"
  to="$(soviez_json_get "$(soviez_migration_traffic_owner_get "$auth_id")" traffic_owner)"
  [[ "$to" == "destination" ]] || \
    soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "traffic_owner must remain destination"

  if [[ "${SOVIEZ_MIG_P22_INJECT_SECOND_LICENSE:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "second license/slot forbidden"
  fi
  if [[ "${SOVIEZ_MIG_P22_INJECT_TOKEN_RESET:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_LICENSE_FINALIZE_FAILED "token reset forbidden"
  fi

  # Idempotent: commit already present + ack → return same receipt (no duplicate transition).
  if [[ -f "$statef" && -f "$ackf" ]]; then
    local prev_state
    prev_state="$(soviez_json_get "$(cat "$statef")" source_license_state 2>/dev/null || true)"
    if [[ "$prev_state" == "migrated_source_archived" ]]; then
      cat "$statef"
      return 0
    fi
  fi

  # Commit-status-unknown: commit file exists, response never returned → resolve without re-commit.
  if [[ -f "$statef" ]] && [[ ! -f "$ackf" ]]; then
    if [[ "${SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS:-0}" == "1" ]]; then
      unset SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS
      export SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS=0
      soviez_migration_die MIGRATION_LICENSE_COMMIT_STATUS_UNKNOWN \
        "license finalize commit present; response lost (inject once)"
    fi
    printf 'acked\n' > "$ackf"
    SOVIEZ_R="$statef" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_R"]
d=json.load(open(p))
d["ack"]="idempotent_retry"
d["duplicate_finalization"]=False
d["commit_status"]="resolved"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(open(p).read())
PY
    return 0
  fi

  # First commit write (before local ack — response-loss window).
  SOVIEZ_OUT="$statef" SOVIEZ_OP="$archive_op_id" SOVIEZ_AID="$auth_id" \
  SOVIEZ_IDEM="$idem_key" SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_license_finalize.v1",
  "archive_operation_id": os.environ["SOVIEZ_OP"],
  "authorization_id": os.environ["SOVIEZ_AID"],
  "idempotency_key": os.environ["SOVIEZ_IDEM"],
  "source_license_state": "migrated_source_archived",
  "destination_sole_production": True,
  "license_count": 1,
  "slot_count": 1,
  "token_consumed": 1,
  "token_reset": False,
  "traffic_owner": "destination",
  "commit_status": "committed",
  "duplicate_finalization": False,
  "finalized_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY

  if [[ "${SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS
    export SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS=0
    soviez_migration_die MIGRATION_LICENSE_FINALIZE_RESPONSE_LOSS \
      "injected response loss after license finalize commit"
  fi

  printf 'acked\n' > "$ackf"
  cat "$statef"
}
