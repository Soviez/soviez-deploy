# shellcheck shell=bash
# Stage operation state machine (Phase 11).

SOVIEZ_STAGE_STATES=(
  created
  preflight
  production_selected
  identity_reserved
  resource_admission
  waiting_for_connection_consent
  device_authorized
  entitlement_checked
  operation_authorized
  tooling_authorized
  tooling_pulled
  ticket_verified
  snapshot_preparing
  database_snapshot_created
  filestore_snapshot_created
  database_restoring
  filestore_restoring
  stage_runtime_created
  neutralization_running
  neutralization_validated
  authorization_consumed
  domain_pending
  ssl_pending
  runtime_validating
  origin_certificate_issued
  remote_completion_pending
  completed
  canceled
  failed_retryable
  recovery_required
  failed_terminal
)

soviez_stage_sm_is_valid() {
  local state="$1" s
  for s in "${SOVIEZ_STAGE_STATES[@]}"; do
    [[ "$s" == "$state" ]] && return 0
  done
  return 1
}

soviez_stage_sm_allowed_next() {
  local from="$1" to="$2"
  case "$from:$to" in
    created:preflight) return 0 ;;
    preflight:production_selected) return 0 ;;
    production_selected:identity_reserved) return 0 ;;
    identity_reserved:resource_admission) return 0 ;;
    resource_admission:waiting_for_connection_consent|resource_admission:device_authorized) return 0 ;;
    waiting_for_connection_consent:device_authorized) return 0 ;;
    device_authorized:entitlement_checked) return 0 ;;
    entitlement_checked:operation_authorized) return 0 ;;
    operation_authorized:tooling_authorized) return 0 ;;
    tooling_authorized:tooling_pulled) return 0 ;;
    tooling_pulled:ticket_verified) return 0 ;;
    ticket_verified:snapshot_preparing) return 0 ;;
    snapshot_preparing:database_snapshot_created) return 0 ;;
    database_snapshot_created:filestore_snapshot_created) return 0 ;;
    filestore_snapshot_created:database_restoring) return 0 ;;
    database_restoring:filestore_restoring) return 0 ;;
    filestore_restoring:stage_runtime_created) return 0 ;;
    stage_runtime_created:neutralization_running) return 0 ;;
    neutralization_running:neutralization_validated) return 0 ;;
    neutralization_validated:authorization_consumed) return 0 ;;
    authorization_consumed:domain_pending) return 0 ;;
    domain_pending:ssl_pending) return 0 ;;
    ssl_pending:runtime_validating) return 0 ;;
    runtime_validating:origin_certificate_issued) return 0 ;;
    origin_certificate_issued:remote_completion_pending) return 0 ;;
    remote_completion_pending:completed) return 0 ;;
    *:failed_retryable|*:failed_terminal|*:canceled|*:recovery_required) return 0 ;;
    "$from":"$to") [[ "$from" == "$to" ]] ;;
    *) return 1 ;;
  esac
}

soviez_stage_sm_assert() {
  local from="$1" to="$2"
  soviez_stage_sm_is_valid "$from" || soviez_die "$SOVIEZ_ERR_STATE" "Invalid stage state: $from"
  soviez_stage_sm_is_valid "$to" || soviez_die "$SOVIEZ_ERR_STATE" "Invalid stage state: $to"
  soviez_stage_sm_allowed_next "$from" "$to" || soviez_die "$SOVIEZ_ERR_STATE" "Illegal stage transition: $from -> $to"
}

soviez_stage_sm_resume_index() {
  local state="$1" i=0 s
  for s in "${SOVIEZ_STAGE_STATES[@]}"; do
    [[ "$s" == "canceled" || "$s" == "failed_retryable" || "$s" == "recovery_required" || "$s" == "failed_terminal" ]] && continue
    [[ "$s" == "$state" ]] && { echo "$i"; return 0; }
    i=$((i + 1))
  done
  echo -1
}

soviez_stage_sm_should_run() {
  local current="$1" target="$2"
  local cur_idx tgt_idx
  cur_idx="$(soviez_stage_sm_resume_index "$current")"
  tgt_idx="$(soviez_stage_sm_resume_index "$target")"
  # Strict < so resume does not re-execute a completed checkpoint.
  [[ "$cur_idx" -ge 0 && "$tgt_idx" -ge 0 && "$cur_idx" -lt "$tgt_idx" ]]
}
