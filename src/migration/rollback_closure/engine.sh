# shellcheck shell=bash

soviez_migration_rollback_window_close_plan() {
  local cutover_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_p22_paths_init
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_ROLLBACK_WINDOW_CLOSE"
  local elig erc
  set +e
  elig="$(soviez_migration_rollback_window_close_eligibility "$cutover_id")"
  erc=$?
  set -e
  SOVIEZ_CID="$cutover_id" SOVIEZ_ELIG="$elig" SOVIEZ_OK="$erc" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
elig=json.loads(os.environ["SOVIEZ_ELIG"])
print(json.dumps({
  "schema":"soviez.migration_rollback_window_close_plan.v1",
  "cutover_id":os.environ["SOVIEZ_CID"],
  "eligible": elig.get("eligible", False),
  "eligibility": elig,
  "confirmation_phrase": f"CLOSE ROLLBACK WINDOW {os.environ['SOVIEZ_CID']}",
  "created_at": os.environ["SOVIEZ_NOW"],
}, separators=(",", ":")))
PY
}

soviez_migration_rollback_window_close() {
  local cutover_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_p22_paths_init
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_ROLLBACK_WINDOW_CLOSE"

  local elig erc
  set +e
  elig="$(soviez_migration_rollback_window_close_eligibility "$cutover_id")"
  erc=$?
  set -e
  if [[ "$erc" -ne 0 ]]; then
    # Already closed → return existing receipt (idempotent).
    if [[ "$(soviez_json_get "$elig" code)" == "MIGRATION_ROLLBACK_WINDOW_ALREADY_CLOSED" ]]; then
      cat "$(soviez_migration_p22_closure_by_cutover_path "$cutover_id")"
      return 0
    fi
    local code
    code="$(soviez_json_get "$elig" code)"
    soviez_migration_die "$code" "rollback window close denied: $(soviez_json_get "$elig" reason 2>/dev/null || echo blockers)"
  fi

  soviez_migration_rollback_window_confirm "$cutover_id"

  # Pre-commit response-loss injection (eligibility+confirm done; commit not yet).
  if [[ "${SOVIEZ_MIG_P22_CLOSURE_PRE_COMMIT_LOSS:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_CLOSURE_PRE_COMMIT_LOSS
    export SOVIEZ_MIG_P22_CLOSURE_PRE_COMMIT_LOSS=0
    soviez_migration_die MIGRATION_ROLLBACK_CLOSE_RESPONSE_LOSS \
      "injected loss after eligibility/confirm before commit"
  fi

  local receipt
  receipt="$(soviez_migration_rollback_window_close_commit "$cutover_id")"

  # Post-commit response-loss: receipt on disk; client never saw response.
  if [[ "${SOVIEZ_MIG_P22_CLOSURE_POST_COMMIT_LOSS:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_CLOSURE_POST_COMMIT_LOSS
    export SOVIEZ_MIG_P22_CLOSURE_POST_COMMIT_LOSS=0
    soviez_migration_die MIGRATION_ROLLBACK_CLOSE_RESPONSE_LOSS \
      "injected loss after rollback-window close commit"
  fi
  printf '%s\n' "$receipt"
}
