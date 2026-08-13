# shellcheck shell=bash

soviez_update_new_op_id() {
  printf 'upd-%s-%s\n' "$(date +%Y%m%d%H%M%S 2>/dev/null || echo 0)" "$(soviez_rand_hex 4 2>/dev/null || echo abcd)"
}

soviez_update_state_write() {
  local op_id="$1" state="$2" checkpoint="${3:-}" extra="${4:-"{}"}"
  local dir sf env_id
  dir="$(soviez_update_op_dir "$op_id")"
  mkdir -p "$dir"
  sf="$(soviez_update_op_state_file "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" SOVIEZ_EX="$extra" \
  SOVIEZ_NOW="$(soviez_utc_now)" python3 - <<'PY' > "$sf"
import json,os
ex=json.loads(os.environ.get("SOVIEZ_EX") or "{}")
doc={
  "operation_id":os.environ["SOVIEZ_OP"],
  "operation_type":"production_update",
  "current_state":os.environ["SOVIEZ_ST"],
  "checkpoint":os.environ.get("SOVIEZ_CP") or "",
  "updated_at":os.environ["SOVIEZ_NOW"],
}
doc.update(ex)
print(json.dumps(doc,separators=(",",":")))
PY
  env_id="$(soviez_json_get "$(cat "$sf")" environment_id 2>/dev/null || true)"
  # Continuous canonical sync (correct apply signature)
  if declare -F soviez_ops_sync_apply >/dev/null 2>&1; then
    soviez_ops_sync_apply "$op_id" "$SOVIEZ_UPDATE_OP_TYPE" "$env_id" "$checkpoint" "transition" "$extra" "$sf" 2>/dev/null || true
  elif declare -F soviez_ops_sync_from_legacy_file >/dev/null 2>&1; then
    soviez_ops_sync_from_legacy_file "$op_id" "$SOVIEZ_UPDATE_OP_TYPE" "$sf" "$env_id" 2>/dev/null || true
  fi
}

soviez_update_cancel_boundary() {
  local checkpoint="$1"
  case "$checkpoint" in
    switching|validating_production) printf 'irreversible\n' ;;
    upgrading_candidate|creating_backup|preparing_candidate) printf 'rollback\n' ;;
    *) printf 'cancelable\n' ;;
  esac
}

# Write state then honor update-specific interrupt injection (return 42 → recovery_required).
soviez_update_checkpoint() {
  local op_id="$1" state="$2" checkpoint="${3:-}" extra="${4:-"{}"}"
  soviez_update_state_write "$op_id" "$state" "$checkpoint" "$extra"
  if declare -F soviez_update_interrupt_checkpoint >/dev/null 2>&1; then
    soviez_update_interrupt_checkpoint "$op_id" "$checkpoint" || return $?
  fi
  return 0
}

soviez_update_run() {
  local target="${1:-}" release_id="${2:-}" offline_pkg="${3:-}" confirm="${4:-0}"
  soviez_update_paths_init

  # S5 corr1 — package lock safe wait (never kill apt/dpkg/unattended-upgrades).
  if declare -F soviez_s5_apt_wait_for_lock >/dev/null 2>&1 \
    && [[ "${SOVIEZ_S5_SKIP_APT_LOCK:-0}" != "1" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" || "${SOVIEZ_S5_ENFORCE_APT_LOCK:-0}" == "1" ]]; then
      local apt_st
      apt_st="$(soviez_s5_apt_wait_for_lock 2>/dev/null || true)"
      if [[ "$apt_st" == "PKG_LOCK_TIMEOUT" ]]; then
        soviez_update_die UPDATE_PREFLIGHT_BLOCKED "PKG_LOCK_TIMEOUT: package manager lock persisted; Needs Action (no kill performed)"
      fi
    fi
  fi

  # Refuse no-target / wildcards before any network or durable state
  if [[ -z "$target" ]]; then
    soviez_update_die UPDATE_TARGET_REQUIRED "Exact Production environment ID required"
  fi
  if soviez_update_refuse_wildcard "$target"; then
    soviez_update_die UPDATE_TARGET_INVALID "Wildcard/all/implicit targeting is refused"
  fi

  local op_id
  op_id="$(soviez_update_new_op_id)"
  mkdir -p "$(soviez_update_op_dir "$op_id")"

  # Non-TTY confirmation
  if [[ ! -t 0 && "$confirm" != "1" && "${SOVIEZ_UPDATE_ASSUME_YES:-0}" != "1" ]]; then
    soviez_update_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Non-TTY update requires --confirm"
  fi

  # Resolve + verify before durable progress (Stage denial happens here)
  # bash 3.2: failed $(die) does not trip set -e — propagate explicitly
  local prod
  prod="$(soviez_update_resolve_target "$target")" || exit $?
  prod="$(soviez_update_verify_identity "$prod")" || exit $?

  soviez_update_state_write "$op_id" created validating_target "{\"environment_id\":\"$(soviez_json_get "$prod" tenant_id)\"}"

  local tenant_id license_id account_id current_digest arch erp_major
  tenant_id="$(soviez_json_get "$prod" tenant_id)"
  license_id="$(soviez_json_get "$prod" license_id)"
  account_id="$(soviez_json_get "$prod" account_id 2>/dev/null || true)"
  current_digest="$(soviez_json_get "$prod" current_digest 2>/dev/null || soviez_json_get "$prod" image_digest 2>/dev/null || true)"
  arch="$(uname -m)"
  erp_major="$(soviez_json_get "$prod" erp_major 2>/dev/null || echo 18)"

  # Explicit target summary
  SOVIEZ_T="$tenant_id" SOVIEZ_L="$license_id" SOVIEZ_D="$current_digest" python3 - <<'PY'
import json,os
print(json.dumps({
  "target_summary":{
    "production_id":os.environ["SOVIEZ_T"],
    "license_id":os.environ["SOVIEZ_L"],
    "current_digest":os.environ.get("SOVIEZ_D"),
  }
},separators=(",",":")))
PY

  # Conflict lock
  if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
    soviez_ops_conflict_check "$SOVIEZ_UPDATE_OP_TYPE" "$tenant_id" "env:$tenant_id" \
      || soviez_update_die UPDATE_CONFLICT "Conflicting operation"
  fi
  if declare -F soviez_ops_lock_acquire >/dev/null 2>&1; then
    soviez_ops_lock_acquire "$tenant_id" "$op_id" "$SOVIEZ_UPDATE_OP_TYPE" 2>/dev/null || true
  fi

  # Canonical create
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" "$SOVIEZ_UPDATE_OP_TYPE" "$tenant_id" "env:$tenant_id" 2>/dev/null || true
  fi

  local manifest ent
  if [[ -n "$offline_pkg" ]]; then
    export SOVIEZ_UPDATE_OFFLINE_MODE=1
    soviez_update_state_write "$op_id" checking_entitlement checking_entitlement "{\"mode\":\"offline\"}"
    manifest="$(soviez_update_offline_import "$offline_pkg" "$op_id" "$license_id" "$tenant_id")" || exit $?
    # Offline entitlement already validated in import
  else
    soviez_update_checkpoint "$op_id" checking_entitlement checking_entitlement "{\"mode\":\"connected\"}" || exit $?
    ent="$(soviez_update_entitlement_check "$license_id" "$tenant_id" "$account_id")" || exit $?
    soviez_update_entitlement_assert "$ent" "$license_id" "$account_id"
    soviez_update_checkpoint "$op_id" resolving_release resolving_release "{}" || exit $?
    manifest="$(soviez_update_release_resolve "${SOVIEZ_UPDATE_CHANNEL:-stable}" "$release_id" "$current_digest")" || exit $?
  fi

  soviez_update_checkpoint "$op_id" validating_manifest validating_manifest "{}" || exit $?
  manifest="$(soviez_update_release_assert "$manifest" "$arch" "$current_digest" "$erp_major")" || exit $?
  local target_digest
  target_digest="$(soviez_json_get "$manifest" digest 2>/dev/null || soviez_json_get "$manifest" image_digest)"
  printf '%s' "$manifest" > "$(soviez_update_op_dir "$op_id")/release.json"
  printf '%s' "$target_digest" > "$(soviez_update_op_dir "$op_id")/target_digest.txt"
  printf '%s' "$prod" > "$(soviez_update_op_dir "$op_id")/production.json"

  soviez_update_checkpoint "$op_id" running_preflight running_preflight "{}" || exit $?
  local pf
  pf="$(soviez_update_preflight "$prod" "$manifest" "$op_id")" || exit $?
  soviez_update_preflight_assert "$pf" "$confirm"
  local cap
  cap="$(soviez_update_capacity_calc "$prod")" || exit $?
  soviez_update_capacity_assert "$cap"

  soviez_update_checkpoint "$op_id" acquiring_artifact acquiring_artifact "{}" || exit $?
  soviez_update_acquire_artifact "$op_id" "$manifest"
  soviez_update_checkpoint "$op_id" validating_artifact validating_artifact "{}" || exit $?
  local got
  got="$(cat "$(soviez_update_op_dir "$op_id")/artifact/digest.txt")"
  [[ "$got" == "$target_digest" ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Pulled digest mismatch"

  soviez_update_checkpoint "$op_id" creating_backup creating_backup "{}" || exit $?
  soviez_update_backup_create "$op_id" "$prod" >/dev/null || exit $?
  soviez_update_backup_verify "$op_id"
  soviez_update_checkpoint "$op_id" cloning_database cloning_database "{}" || exit $?
  soviez_update_checkpoint "$op_id" cloning_filestore cloning_filestore "{}" || exit $?

  soviez_update_checkpoint "$op_id" preparing_candidate preparing_candidate "{}" || exit $?
  soviez_update_candidate_create "$op_id" "$prod" "$target_digest" >/dev/null || exit $?
  soviez_update_checkpoint "$op_id" upgrading_candidate upgrading_candidate "{}" || exit $?
  if ! ( soviez_update_upgrade_candidate "$op_id" "$target_digest" >/dev/null ); then
    soviez_update_state_write "$op_id" failed_retryable candidate_upgrade_failed "{}"
    # Production untouched — candidate may remain for retry
    soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Candidate upgrade failed; Production preserved"
  fi

  soviez_update_checkpoint "$op_id" starting_candidate starting_candidate "{}" || exit $?
  soviez_update_checkpoint "$op_id" validating_candidate validating_candidate "{}" || exit $?
  if ! ( soviez_update_validate_candidate "$op_id" "$prod" "$target_digest" >/dev/null ); then
    soviez_update_state_write "$op_id" rollback_running validation_failed "{}"
    ( soviez_update_rollback "$op_id" >/dev/null ) || true
    soviez_update_candidate_cleanup "$op_id" || true
    soviez_update_die UPDATE_CANDIDATE_VALIDATION_FAILED "Candidate validation failed; Production preserved"
  fi

  soviez_update_checkpoint "$op_id" waiting_for_switch waiting_for_switch "{}" || exit $?
  if [[ "$confirm" != "1" && "${SOVIEZ_UPDATE_ASSUME_YES:-0}" != "1" && -t 0 ]]; then
    :
  fi
  [[ "$confirm" == "1" || "${SOVIEZ_UPDATE_ASSUME_YES:-0}" == "1" || -t 0 ]] \
    || soviez_update_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Switch requires confirmation"

  # Revalidate digest before switch
  [[ "$(cat "$(soviez_update_op_dir "$op_id")/target_digest.txt")" == "$target_digest" ]] \
    || soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Target digest changed before switch"

  soviez_update_checkpoint "$op_id" preparing_switch preparing_switch "{}" || exit $?
  soviez_update_checkpoint "$op_id" switching switching "{}" || exit $?
  if ! ( soviez_update_switch "$op_id" "$prod" "$target_digest" >/dev/null ); then
    soviez_update_checkpoint "$op_id" rollback_running rollback_running "{}" || true
    if ! ( soviez_update_rollback "$op_id" >/dev/null ); then
      soviez_update_state_write "$op_id" recovery_required rollback_failed "{}"
      soviez_update_die UPDATE_ROLLBACK_FAILED "Rollback after switch failure failed"
    fi
    soviez_update_checkpoint "$op_id" validating_rollback validating_rollback "{}" || true
    soviez_update_die UPDATE_SWITCH_FAILED "Switch failed; rollback completed"
  fi

  soviez_update_checkpoint "$op_id" validating_production validating_production "{}" || exit $?

  # Security Gate S5 — post-switch network/PDF/DB matrix (containers-up alone is insufficient).
  # Enforce on Production paths; skip Phase 15 fixture unit tests unless SOVIEZ_S5_ENFORCE=1.
  local s5_enforce=0
  if [[ "${SOVIEZ_S5_ENFORCE:-0}" == "1" ]]; then
    s5_enforce=1
  elif [[ "${SOVIEZ_TEST_MODE:-0}" != "1" && "${SOVIEZ_S5_SKIP_UPDATE_GATE:-0}" != "1" ]]; then
    s5_enforce=1
  fi
  if [[ "$s5_enforce" -eq 1 ]] \
    && declare -F soviez_security_validate_update_safety >/dev/null 2>&1; then
    export SOVIEZ_S5_OP_ID="$op_id"
    local s5_result
    s5_result="$(soviez_security_validate_update_safety "$op_id" 2>/dev/null || true)"
    case "$s5_result" in
      PASS) ;;
      ROLLED_BACK)
        soviez_update_state_write "$op_id" rolled_back s5_network_validation "{}"
        soviez_update_die UPDATE_ROLLBACK_COMPLETED "S5 post-update validation failed; rolled back"
        ;;
      *)
        soviez_update_state_write "$op_id" needs_action s5_network_validation "{}"
        soviez_update_die UPDATE_POST_VALIDATION_FAILED "S5 post-update validation failed (${s5_result:-FAIL}); not declaring success"
        ;;
    esac
  fi

  soviez_update_state_write "$op_id" completed completed "{}"
  if declare -F soviez_ops_sync_terminal >/dev/null 2>&1; then
    soviez_ops_sync_terminal "$op_id" "$SOVIEZ_UPDATE_OP_TYPE" "$tenant_id" completed "$(soviez_update_op_state_file "$op_id")" 2>/dev/null || true
  fi
  # Schedule image cleanup after safety window (separate op; does not mutate ERP update terminal state)
  if declare -F soviez_image_cleanup_schedule >/dev/null 2>&1; then
    local prev_d
    prev_d="$(soviez_json_get "$prod" current_digest 2>/dev/null || soviez_json_get "$prod" image_digest 2>/dev/null || true)"
    soviez_image_cleanup_schedule "$op_id" "$tenant_id" "$target_digest" "$prev_d" >/dev/null 2>&1 || true
  fi

  local safety
  safety="$(soviez_update_safety_window_info "$op_id")"
  SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_TD="$target_digest" SOVIEZ_SF="$safety" python3 - <<'PY'
import json,os
print(json.dumps({
  "ok":True,
  "code":"UPDATE_COMPLETED",
  "operation_id":os.environ["SOVIEZ_OP"],
  "production_id":os.environ["SOVIEZ_T"],
  "target_digest":os.environ["SOVIEZ_TD"],
  "safety_window":json.loads(os.environ["SOVIEZ_SF"]),
},separators=(",",":")))
PY
}
