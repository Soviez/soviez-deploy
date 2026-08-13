# shellcheck shell=bash

soviez_cmd_new_run() {
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  [[ -n "$op_id" ]] || op_id="$(soviez_op_create)"
  export SOVIEZ_ACTIVE_OP_ID="$op_id"
  soviez_op_acquire_lock "$op_id"
  trap '[[ -n "${SOVIEZ_ACTIVE_OP_ID:-}" ]] && soviez_op_release_lock "$SOVIEZ_ACTIVE_OP_ID"' EXIT

  local state
  state="$(soviez_op_read_state "$op_id")"
  soviez_ui_dashboard_show "$state"

  if soviez_sm_should_run_step "$state" preflight; then
    soviez_op_transition "$op_id" preflight
    soviez_preflight_run
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" waiting_for_connection_consent; then
    soviez_op_transition "$op_id" waiting_for_connection_consent
    soviez_ui_consent_prompt
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" device_authorization_pending; then
    soviez_op_transition "$op_id" device_authorization_pending
    local start_json cred_json
    start_json="$(soviez_device_client_start)"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_START="$start_json" python3 - <<'PY'
import json, os
print(json.dumps({"device_auth": json.loads(os.environ["SOVIEZ_START"])}))
PY
)"
    if ! soviez_device_client_load_credential >/dev/null 2>&1; then
      cred_json="$(soviez_device_client_authorize "$start_json")"
      soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
        "$(SOVIEZ_CRED="$(soviez_json_get "$cred_json" device_id)" python3 - <<'PY'
import json, os
print(json.dumps({"device_id": os.environ["SOVIEZ_CRED"]}))
PY
)"
    fi
    soviez_op_transition "$op_id" device_authorized
  fi
  state="$(soviez_op_read_state "$op_id")"

  local slot_id release_id digest image_ref container db_name tenant_id fingerprint activation_key
  if soviez_sm_should_run_step "$state" slot_reserved; then
    local reserve_json
    reserve_json="$(soviez_slots_reserve "$op_id")"
    slot_id="$(soviez_json_get "$reserve_json" slot_id)"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_SLOT="$slot_id" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"]}))
PY
)"
    soviez_op_transition "$op_id" slot_reserved
  else
    slot_id="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" slot_id)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" release_resolved; then
    local release_json
    release_json="$(soviez_registry_resolve_release "$SOVIEZ_CLI_CHANNEL")"
    release_id="$(soviez_json_get "$release_json" release_id)"
    digest="$(soviez_json_get "$release_json" digest)"
    soviez_manifest_verify "$release_json" "$digest"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_RID="$release_id" SOVIEZ_DIGEST="$digest" python3 - <<'PY'
import json, os
print(json.dumps({"release_id": os.environ["SOVIEZ_RID"], "digest": os.environ["SOVIEZ_DIGEST"]}))
PY
)"
    soviez_op_transition "$op_id" release_resolved
  else
    digest="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" digest)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" image_pull_authorized; then
    local pull_json session_id registry_user registry_pass gateway_url repository image_ref fields
    local release_id_cur
    release_id_cur="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" release_id)"
    pull_json="$(soviez_registry_create_pull_session "$release_id_cur" "$digest" "$op_id" "production_new")"
    fields="$(soviez_registry_session_fields "$pull_json")"
    IFS='|' read -r session_id registry_user registry_pass gateway_url repository _digest_field image_ref <<<"$fields"
    [[ -n "$session_id" && -n "$registry_pass" && -n "$image_ref" ]] || \
      soviez_die "$SOVIEZ_ERR_API" "Registry pull session response incomplete"
    if [[ -n "${SOVIEZ_REGISTRY_GATEWAY_URL:-}" ]]; then
      gateway_url="$SOVIEZ_REGISTRY_GATEWAY_URL"
    elif [[ -n "$gateway_url" ]]; then
      export SOVIEZ_REGISTRY_GATEWAY_URL="$gateway_url"
    fi
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_SID="$session_id" SOVIEZ_IMG="$image_ref" SOVIEZ_REPO="${repository:-}" python3 - <<'PY'
import json, os
print(json.dumps({
  "pull_session_id": os.environ["SOVIEZ_SID"],
  "image_ref": os.environ["SOVIEZ_IMG"],
  "repository": os.environ.get("SOVIEZ_REPO", ""),
}))
PY
)"
    soviez_op_transition "$op_id" image_pull_authorized
    soviez_pull_client_run "$image_ref" "$registry_user" "$registry_pass" "$digest" "$gateway_url"
    unset registry_pass
    soviez_registry_complete_pull_session "$session_id" || true
    soviez_op_transition "$op_id" image_pulled "$(SOVIEZ_DIGEST="$digest" python3 - <<'PY'
import json, os
print(json.dumps({"digest": os.environ["SOVIEZ_DIGEST"]}))
PY
)"
  else
    image_ref="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" image_ref)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" tenant_identity_created; then
    tenant_id="$(soviez_tenant_identity_create "$op_id")"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_TID="$tenant_id" python3 - <<'PY'
import json, os
print(json.dumps({"tenant_id": os.environ["SOVIEZ_TID"]}))
PY
)"
    soviez_op_transition "$op_id" tenant_identity_created
  else
    tenant_id="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" tenant_id 2>/dev/null || soviez_tenant_identity_load || true)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" database_provisioned; then
    db_name="$(soviez_database_provision "$op_id")"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_DB="$db_name" python3 - <<'PY'
import json, os
print(json.dumps({"db_name": os.environ["SOVIEZ_DB"]}))
PY
)"
    soviez_op_transition "$op_id" database_provisioned
  else
    db_name="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" db_name 2>/dev/null || soviez_tenant_secret_read db_name || true)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" container_started; then
    container="$(soviez_docker_provision_start "$op_id" "$image_ref")"
    soviez_json_merge_file "$(soviez_operation_state_file "$op_id")" \
      "$(SOVIEZ_CTR="$container" python3 - <<'PY'
import json, os
print(json.dumps({"container": os.environ["SOVIEZ_CTR"]}))
PY
)"
    soviez_op_transition "$op_id" container_started
  else
    container="$(soviez_json_get "$(cat "$(soviez_operation_state_file "$op_id")")" container 2>/dev/null || printf 'soviez-web-%s' "$op_id")"
  fi
  state="$(soviez_op_read_state "$op_id")"


  # Security Gate S1 — after containers started, before completed.
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_SEC_FORCE_GATE:-0}" != "1" ]]; then
    local _app_sec _adm_sec
    _app_sec="$(soviez_tenant_secret_read db_password 2>/dev/null || true)"
    _adm_sec="$(soviez_tenant_secret_read pg_admin_password 2>/dev/null || true)"
    if declare -F soviez_sec_password_assert_not_weak >/dev/null 2>&1; then
      [[ -n "$_app_sec" ]] && soviez_sec_password_assert_not_weak "$_app_sec" "db_password"
      [[ -n "$_adm_sec" ]] && soviez_sec_password_assert_not_weak "$_adm_sec" "pg_admin_password"
    fi
  else
    local _pg _web
    _pg="${SOVIEZ_DB_CONTAINER:-soviez-db-${op_id}}"
    _web="${container:-soviez-web-${op_id}}"
    if docker inspect "$_pg" >/dev/null 2>&1 && docker inspect "$_web" >/dev/null 2>&1; then
      export SOVIEZ_SEC_MODE="${SOVIEZ_SEC_MODE:-production}"
      export SOVIEZ_SEC_PG_CONTAINER="$_pg"
      export SOVIEZ_SEC_ODOO_CONTAINER="$_web"
      export SOVIEZ_SEC_PG_ADMIN_PASS="$(soviez_tenant_secret_read pg_admin_password 2>/dev/null || true)"
      export SOVIEZ_SEC_PG_APP_PASS="$(soviez_tenant_secret_read db_password 2>/dev/null || true)"
      export SOVIEZ_SEC_REPORT_DIR="${SOVIEZ_ROOT:-.}/security/reports"
      if declare -F soviez_security_gate_require_pass >/dev/null 2>&1; then
        soviez_security_gate_require_pass || return 1
      elif declare -F soviez_security_validate_critical_containment >/dev/null 2>&1; then
        soviez_security_validate_critical_containment || return 1
      fi
    fi
  fi

  local domain="${SOVIEZ_CLI_DOMAIN:-test.local.soviez}"
  if soviez_sm_should_run_step "$state" instance_provisioned; then
    if [[ -n "$SOVIEZ_CLI_DOMAIN" ]]; then
      soviez_op_transition "$op_id" domain_pending
      soviez_op_transition "$op_id" waiting_for_dns
      soviez_op_transition "$op_id" ssl_pending
      local ssl_lines cert key ca
      ssl_lines="$(soviez_ssl_local_issue_cert "$domain")"
      cert="$(printf '%s\n' "$ssl_lines" | sed -n '1p')"
      key="$(printf '%s\n' "$ssl_lines" | sed -n '2p')"
      ca="$(printf '%s\n' "$ssl_lines" | sed -n '3p')"
      soviez_ssl_validate_chain "$cert" "$ca"
      soviez_nginx_render_config "$domain" "$container:8069"
    fi
    soviez_slots_instance_provisioned "$slot_id" >/dev/null
    soviez_op_transition "$op_id" instance_provisioned "$(SOVIEZ_DOMAIN="$domain" python3 - <<'PY'
import json, os
print(json.dumps({"domain": os.environ["SOVIEZ_DOMAIN"]}))
PY
)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  if soviez_sm_should_run_step "$state" fingerprint_bound; then
    fingerprint="$(soviez_license_compute_fingerprint "$op_id" "$tenant_id")"
    soviez_slots_bind_fingerprint "$slot_id" "$fingerprint" >/dev/null
    soviez_op_transition "$op_id" fingerprint_bound "$(SOVIEZ_FP="$fingerprint" python3 - <<'PY'
import json, os
print(json.dumps({"fingerprint": os.environ["SOVIEZ_FP"]}))
PY
)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  local method
  method="$(soviez_license_choose_activation_method "$SOVIEZ_CLI_ACTIVATION_METHOD")"
  if soviez_sm_should_run_step "$state" license_issued; then
    soviez_op_transition "$op_id" waiting_for_activation_method
    soviez_slots_activation_method "$slot_id" "$method" >/dev/null
    local license_json
    license_json="$(soviez_slots_issue_license "$slot_id")"
    activation_key="$(soviez_json_get "$license_json" activation_key)"
    soviez_tenant_secret_write "activation_key" "$activation_key"
    soviez_op_transition "$op_id" license_issued
  else
    activation_key="$(soviez_tenant_secret_read activation_key 2>/dev/null || true)"
  fi
  state="$(soviez_op_read_state "$op_id")"

  state="$(soviez_op_read_state "$op_id")"
  if [[ "$method" == "automatic" ]]; then
    if soviez_sm_should_run_step "$state" activated; then
      soviez_op_transition "$op_id" activation_pending
      soviez_license_activate_via_odoo "$container" "$db_name" "$activation_key"
      soviez_op_transition "$op_id" activated
      soviez_license_send_activation_ack "$slot_id"
    fi
    state="$(soviez_op_read_state "$op_id")"
    if soviez_sm_should_run_step "$state" completed; then
      soviez_op_transition "$op_id" validating
      soviez_op_transition "$op_id" completed
    fi
  else
    if soviez_sm_should_run_step "$state" completed_activation_pending; then
      soviez_op_transition "$op_id" activation_pending
      soviez_op_transition "$op_id" manual_activation_pending
      soviez_op_transition "$op_id" completed_activation_pending
    fi
  fi

  soviez_log_info "Operation $op_id finished in state $(soviez_op_read_state "$op_id")"
  printf '%s\n' "$op_id"
}
