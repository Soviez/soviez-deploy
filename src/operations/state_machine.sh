# shellcheck shell=bash

SOVIEZ_NEW_STATES=(
  created
  preflight
  waiting_for_connection_consent
  device_authorization_pending
  device_authorized
  slot_reserved
  release_resolved
  image_pull_authorized
  image_pulled
  tenant_identity_created
  database_provisioned
  container_started
  domain_pending
  waiting_for_dns
  ssl_pending
  instance_provisioned
  fingerprint_bound
  waiting_for_activation_method
  license_issued
  activation_pending
  activated
  manual_activation_pending
  validating
  completed
  completed_activation_pending
  canceled
  failed_retryable
  recovery_required
  failed_terminal
)

soviez_sm_is_valid_state() {
  local state="$1"
  local s
  for s in "${SOVIEZ_NEW_STATES[@]}"; do
    [[ "$s" == "$state" ]] && return 0
  done
  return 1
}

soviez_sm_allowed_next() {
  local from="$1"
  local to="$2"
  case "$from:$to" in
    created:preflight|preflight:waiting_for_connection_consent) return 0 ;;
    waiting_for_connection_consent:device_authorization_pending) return 0 ;;
    device_authorization_pending:device_authorized) return 0 ;;
    device_authorized:slot_reserved) return 0 ;;
    slot_reserved:release_resolved) return 0 ;;
    release_resolved:image_pull_authorized) return 0 ;;
    image_pull_authorized:image_pulled) return 0 ;;
    image_pulled:tenant_identity_created) return 0 ;;
    tenant_identity_created:database_provisioned) return 0 ;;
    database_provisioned:container_started) return 0 ;;
    container_started:domain_pending|container_started:instance_provisioned) return 0 ;;
    domain_pending:waiting_for_dns) return 0 ;;
    waiting_for_dns:ssl_pending) return 0 ;;
    ssl_pending:instance_provisioned) return 0 ;;
    instance_provisioned:fingerprint_bound) return 0 ;;
    fingerprint_bound:waiting_for_activation_method) return 0 ;;
    waiting_for_activation_method:license_issued) return 0 ;;
    license_issued:activation_pending) return 0 ;;
    activation_pending:activated|activation_pending:manual_activation_pending) return 0 ;;
    manual_activation_pending:completed_activation_pending) return 0 ;;
    activated:validating|completed_activation_pending:validating) return 0 ;;
    validating:completed) return 0 ;;
    *:failed_retryable|*:failed_terminal|*:canceled|*:recovery_required) return 0 ;;
    "$from":"$to")
      [[ "$from" == "$to" ]]
      ;;
    *) return 1 ;;
  esac
}

soviez_sm_assert_transition() {
  local from="$1"
  local to="$2"
  soviez_sm_is_valid_state "$from" || soviez_die "$SOVIEZ_ERR_STATE" "Invalid state: $from"
  soviez_sm_is_valid_state "$to" || soviez_die "$SOVIEZ_ERR_STATE" "Invalid state: $to"
  soviez_sm_allowed_next "$from" "$to" || soviez_die "$SOVIEZ_ERR_STATE" "Illegal transition: $from -> $to"
}

soviez_sm_resume_index() {
  local state="$1"
  local i=0
  for s in created preflight waiting_for_connection_consent device_authorization_pending device_authorized slot_reserved release_resolved image_pull_authorized image_pulled tenant_identity_created database_provisioned container_started domain_pending waiting_for_dns ssl_pending instance_provisioned fingerprint_bound waiting_for_activation_method license_issued activation_pending activated manual_activation_pending validating completed completed_activation_pending; do
    [[ "$s" == "$state" ]] && { echo "$i"; return 0; }
    i=$((i + 1))
  done
  echo -1
}

soviez_sm_should_run_step() {
  local current="$1"
  local target="$2"
  local cur_idx tgt_idx
  cur_idx="$(soviez_sm_resume_index "$current")"
  tgt_idx="$(soviez_sm_resume_index "$target")"
  [[ "$cur_idx" -ge 0 && "$tgt_idx" -ge 0 && "$cur_idx" -le "$tgt_idx" ]]
}
