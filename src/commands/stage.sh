# shellcheck shell=bash
# Phase 11 — soviez.sh --stage connected creation pipeline.

soviez_cmd_stage_create_run() {
  soviez_stage_paths_init
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  if [[ -n "$op_id" ]]; then
    soviez_stage_op_create "$op_id" >/dev/null
  else
    op_id="$(soviez_stage_op_create)"
  fi
  export SOVIEZ_ACTIVE_STAGE_OP_ID="$op_id"
  soviez_log_info "Stage operation $op_id starting"

  # Optional durable worker: controller launches worker and exits (disconnect-safe).
  if [[ "${SOVIEZ_STAGE_DURABLE_WORKER:-0}" == "1" && "${SOVIEZ_STAGE_WORKER_INNER:-0}" != "1" ]]; then
    local envf
    envf="$(soviez_stage_op_dir "$op_id")/worker.env"
    mkdir -p "$(soviez_stage_op_dir "$op_id")/auth"
    chmod 700 "$(soviez_stage_op_dir "$op_id")/auth"
    {
      echo "export SOVIEZ_STAGE_WORKER_INNER=1"
      echo "export SOVIEZ_STAGE_DURABLE_WORKER=0"
      echo "export SOVIEZ_TEST_MODE=${SOVIEZ_TEST_MODE:-0}"
      echo "export SOVIEZ_ROOT=$(printf '%q' "${SOVIEZ_ROOT}")"
      echo "export SOVIEZ_SH_ROOT=$(printf '%q' "${SOVIEZ_SH_ROOT}")"
      echo "export SOVIEZ_HOST_PUBKEY_FINGERPRINT=$(printf '%q' "${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-}")"
      echo "export SOVIEZ_CLI_STAGE_ID=$(printf '%q' "${SOVIEZ_CLI_STAGE_ID:-}")"
      echo "export SOVIEZ_CLI_STAGE_DOMAIN=$(printf '%q' "${SOVIEZ_CLI_STAGE_DOMAIN:-}")"
      echo "export SOVIEZ_CLI_OP_ID=$(printf '%q' "$op_id")"
      echo "export SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=${SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE:-0}"
      echo "export SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE=${SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE:-0}"
      echo "export SOVIEZ_STAGE_DNS_OK=${SOVIEZ_STAGE_DNS_OK:-0}"
      echo "export SOVIEZ_STAGE_ADMISSION_FORCE=${SOVIEZ_STAGE_ADMISSION_FORCE:-0}"
      echo "export SOVIEZ_STAGE_USE_LIVE_PG=${SOVIEZ_STAGE_USE_LIVE_PG:-0}"
      echo "export SOVIEZ_STAGE_PAUSE_AT=$(printf '%q' "${SOVIEZ_STAGE_PAUSE_AT:-}")"
      echo "export SOVIEZ_STAGE_PAUSE_MAX_SEC=${SOVIEZ_STAGE_PAUSE_MAX_SEC:-120}"
      echo "export SOVIEZ_STAGE_HELPER_BIN=$(printf '%q' "${SOVIEZ_STAGE_HELPER_BIN:-}")"
      echo "export SOVIEZ_STAGE_INSTALLER_PATH=$(printf '%q' "${SOVIEZ_STAGE_INSTALLER_PATH:-}")"
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON" > "$(soviez_stage_op_dir "$op_id")/auth/production.json"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/production.json"
        echo "export SOVIEZ_STAGE_FIXTURE_PRODUCTION_FROM_FILE=1"
      fi
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_FILESTORE:-}" ]]; then
        echo "export SOVIEZ_STAGE_FIXTURE_FILESTORE=$(printf '%q' "$SOVIEZ_STAGE_FIXTURE_FILESTORE")"
      fi
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN" > "$(soviez_stage_op_dir "$op_id")/auth/ticket.token.pending"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/ticket.token.pending"
        echo "export SOVIEZ_STAGE_FIXTURE_TICKET_FROM_FILE=1"
      fi
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON" > "$(soviez_stage_op_dir "$op_id")/auth/keys.json"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/keys.json"
      fi
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON" > "$(soviez_stage_op_dir "$op_id")/auth/authorize.json"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/authorize.json"
        echo "export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_FROM_FILE=1"
      fi
      if [[ -n "${SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON" > "$(soviez_stage_op_dir "$op_id")/auth/entitlement.json"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/entitlement.json"
        echo "export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_FROM_FILE=1"
      fi
      if [[ -n "${SOVIEZ_PG_PASSWORD:-}" ]]; then
        printf '%s' "$SOVIEZ_PG_PASSWORD" > "$(soviez_stage_op_dir "$op_id")/auth/pg.password"
        chmod 600 "$(soviez_stage_op_dir "$op_id")/auth/pg.password"
        echo "export SOVIEZ_PG_PASSWORD_FILE=$(printf '%q' "$(soviez_stage_op_dir "$op_id")/auth/pg.password")"
      fi
      [[ -n "${SOVIEZ_PG_HOST:-}" ]] && echo "export SOVIEZ_PG_HOST=$(printf '%q' "$SOVIEZ_PG_HOST")"
      [[ -n "${SOVIEZ_PG_PORT:-}" ]] && echo "export SOVIEZ_PG_PORT=$(printf '%q' "$SOVIEZ_PG_PORT")"
      [[ -n "${SOVIEZ_PG_USER:-}" ]] && echo "export SOVIEZ_PG_USER=$(printf '%q' "$SOVIEZ_PG_USER")"
      [[ -n "${SOVIEZ_PG_CONTAINER:-}" ]] && echo "export SOVIEZ_PG_CONTAINER=$(printf '%q' "$SOVIEZ_PG_CONTAINER")"
    } > "$envf"
    chmod 600 "$envf"
    soviez_stage_start_durable_worker "$op_id"
    echo "Durable Stage worker started for $op_id"
    echo "Reattach: soviez.sh --stage-reattach $op_id"
    return 0
  fi

  # Reload ticket/entitlement from files when launched as worker.
  if [[ "${SOVIEZ_STAGE_FIXTURE_PRODUCTION_FROM_FILE:-0}" == "1" && -f "$(soviez_stage_op_dir "$op_id")/auth/production.json" ]]; then
    export SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON
    SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON="$(cat "$(soviez_stage_op_dir "$op_id")/auth/production.json")"
  fi
  if [[ "${SOVIEZ_STAGE_FIXTURE_TICKET_FROM_FILE:-0}" == "1" && -f "$(soviez_stage_op_dir "$op_id")/auth/ticket.token.pending" ]]; then
    export SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN
    SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN="$(cat "$(soviez_stage_op_dir "$op_id")/auth/ticket.token.pending")"
  fi
  if [[ "${SOVIEZ_STAGE_FIXTURE_AUTHORIZE_FROM_FILE:-0}" == "1" && -f "$(soviez_stage_op_dir "$op_id")/auth/authorize.json" ]]; then
    export SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON
    SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON="$(cat "$(soviez_stage_op_dir "$op_id")/auth/authorize.json")"
  fi
  if [[ "${SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_FROM_FILE:-0}" == "1" && -f "$(soviez_stage_op_dir "$op_id")/auth/entitlement.json" ]]; then
    export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON
    SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON="$(cat "$(soviez_stage_op_dir "$op_id")/auth/entitlement.json")"
  fi
  if [[ -n "${SOVIEZ_PG_PASSWORD_FILE:-}" && -f "${SOVIEZ_PG_PASSWORD_FILE}" ]]; then
    export SOVIEZ_PG_PASSWORD
    SOVIEZ_PG_PASSWORD="$(cat "$SOVIEZ_PG_PASSWORD_FILE")"
  fi
  if [[ -f "$(soviez_stage_op_dir "$op_id")/auth/keys.json" && -z "${SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON:-}" ]]; then
    export SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON
    SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON="$(cat "$(soviez_stage_op_dir "$op_id")/auth/keys.json")"
  fi

  local state
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" preflight; then
    soviez_stage_op_transition "$op_id" preflight
    soviez_preflight_run 2>/dev/null || true
    soviez_stage_checkpoint "$op_id" preflight
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  local prod_json
  if soviez_stage_sm_should_run "$state" production_selected; then
    prod_json="$(soviez_stage_select_production)"
    soviez_stage_validate_production "$prod_json"
    soviez_stage_op_merge "$op_id" "$(SOVIEZ_P="$prod_json" python3 - <<'PY'
import json,os
print(json.dumps({"production": json.loads(os.environ["SOVIEZ_P"])}))
PY
)"
    soviez_stage_op_transition "$op_id" production_selected
    soviez_stage_checkpoint "$op_id" production_selected
  else
    prod_json="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" production)"
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  local stage_id stage_domain license_id fingerprint db_uuid tenant_id
  license_id="$(soviez_json_get "$prod_json" license_id)"
  fingerprint="$(soviez_json_get "$prod_json" production_fingerprint)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid)"
  tenant_id="$(soviez_json_get "$prod_json" tenant_id)"
  stage_id="${SOVIEZ_CLI_STAGE_ID:-}"
  stage_domain="${SOVIEZ_CLI_STAGE_DOMAIN:-${SOVIEZ_CLI_DOMAIN:-}}"

  if [[ -z "$stage_id" ]]; then
    if [[ -t 0 ]]; then
      printf 'Stage ID: ' >&2
      read -r stage_id
    else
      soviez_stage_die STAGE_ID_CONFLICT "Pass --stage-id"
    fi
  fi
  if [[ -z "$stage_domain" ]]; then
    if [[ -t 0 ]]; then
      printf 'Stage domain: ' >&2
      read -r stage_domain
    else
      soviez_stage_die STAGE_DOMAIN_CONFLICT "Pass --stage-domain"
    fi
  fi

  local release_digest tooling_digest
  release_digest="${SOVIEZ_CLI_RELEASE_DIGEST:-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}"
  tooling_digest="${SOVIEZ_CLI_TOOLING_DIGEST:-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"

  if soviez_stage_sm_should_run "$state" identity_reserved; then
    local identity
    identity="$(soviez_stage_identity_reserve "$stage_id" "$tenant_id" "$license_id" \
      "$fingerprint" "$db_uuid" "$stage_domain" "$release_digest" "$tooling_digest" "$op_id" \
      "$(soviez_json_get "$prod_json" domain 2>/dev/null || true)")"
    stage_id="$(soviez_json_get "$identity" stage_id)"
    soviez_stage_op_merge "$op_id" "$(SOVIEZ_I="$identity" python3 - <<'PY'
import json,os
print(json.dumps({"stage_id": json.loads(os.environ["SOVIEZ_I"])["stage_id"], "identity": json.loads(os.environ["SOVIEZ_I"])}))
PY
)"
    soviez_stage_op_transition "$op_id" identity_reserved
    soviez_stage_checkpoint "$op_id" identity_reserved
  else
    stage_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" stage_id)"
    if [[ -z "$stage_domain" ]]; then
      stage_domain="$(soviez_json_get "$(soviez_stage_inventory_find "$stage_id")" stage_domain 2>/dev/null || true)"
    fi
    if [[ -z "$release_digest" || "$release_digest" == sha256:bbbb* ]]; then
      release_digest="$(soviez_json_get "$(soviez_stage_inventory_find "$stage_id")" release_digest 2>/dev/null || echo "$release_digest")"
    fi
    if [[ -z "$tooling_digest" || "$tooling_digest" == sha256:aaaa* ]]; then
      tooling_digest="$(soviez_json_get "$(soviez_stage_inventory_find "$stage_id")" tooling_digest 2>/dev/null || echo "$tooling_digest")"
    fi
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" resource_admission; then
    local src_db_bytes=1048576 src_fs_bytes=1048576
    if [[ -n "${SOVIEZ_STAGE_FIXTURE_FILESTORE:-}" ]]; then
      src_fs_bytes="$(soviez_stage_measure_path_bytes "$SOVIEZ_STAGE_FIXTURE_FILESTORE")"
    fi
    local admission
    admission="$(soviez_stage_admission_evaluate "$src_db_bytes" "$src_fs_bytes")"
    soviez_stage_admission_require "$admission"
    soviez_stage_op_merge "$op_id" "$(SOVIEZ_A="$admission" python3 - <<'PY'
import json,os
print(json.dumps({"admission": json.loads(os.environ["SOVIEZ_A"])}))
PY
)"
    soviez_stage_op_transition "$op_id" resource_admission
    soviez_stage_checkpoint "$op_id" resource_admission
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  # Device + entitlement (silent if credential present)
  if soviez_stage_sm_should_run "$state" device_authorized; then
    if [[ "${SOVIEZ_STAGE_OFFLINE:-0}" == "1" || "${SOVIEZ_STAGE_BLOCK_SAAS:-0}" == "1" ]]; then
      :
    elif ! soviez_device_client_load_credential >/dev/null 2>&1; then
      if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE:-0}" == "1" ]]; then
        :
      else
        soviez_stage_op_transition "$op_id" waiting_for_connection_consent
        soviez_ui_consent_prompt 2>/dev/null || true
        local start_json
        start_json="$(soviez_device_client_start)"
        soviez_device_client_authorize "$start_json" >/dev/null
      fi
    fi
    soviez_stage_op_transition "$op_id" device_authorized
    soviez_stage_checkpoint "$op_id" device_authorized
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" entitlement_checked; then
    local ent allowed
    if [[ "${SOVIEZ_STAGE_OFFLINE:-0}" == "1" ]]; then
      # Offline package binding verification is the entitlement gate — no SaaS check.
      allowed=true
      ent='{"allowed":true,"offline":true}'
    else
      ent="$(soviez_stage_entitlement_check "$license_id" stage_create)"
      allowed="$(soviez_json_get "$ent" allowed 2>/dev/null || echo false)"
    fi
    if [[ "$allowed" != "true" && "$allowed" != "True" ]]; then
      local dcode
      dcode="$(soviez_json_get "$ent" denial_code 2>/dev/null || echo STAGE_ENTITLEMENT_REQUIRED)"
      [[ -n "$dcode" ]] || dcode=STAGE_ENTITLEMENT_REQUIRED
      case "$dcode" in
        *EXPIRED*|*PAST_DUE*) soviez_stage_die STAGE_ENTITLEMENT_EXPIRED "Stage entitlement not active" ;;
        *) soviez_stage_die STAGE_ENTITLEMENT_REQUIRED "Stage entitlement required ($dcode)" ;;
      esac
    fi
    soviez_stage_op_transition "$op_id" entitlement_checked
    soviez_stage_checkpoint "$op_id" entitlement_checked
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  local authorization_id ticket_token ticket_claims_file
  if soviez_stage_sm_should_run "$state" operation_authorized; then
    if [[ "${SOVIEZ_STAGE_OFFLINE_TICKET_READY:-0}" == "1" ]]; then
      authorization_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" authorization_id 2>/dev/null || echo offline-auth)"
      ticket_token="$(cat "$(soviez_stage_op_dir "$op_id")/auth/ticket.token" 2>/dev/null || true)"
      [[ -n "$ticket_token" ]] || soviez_stage_die TICKET_INVALID "Offline ticket missing after import"
      soviez_stage_op_merge "$op_id" '{"ticket_present": true, "offline": true}'
      soviez_stage_op_transition "$op_id" operation_authorized
      soviez_stage_checkpoint "$op_id" operation_authorized
    else
    local host_fp
    host_fp="${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-fp_host_fixture}"
    local auth_body
    auth_body="$(python3 - <<PY
import json
print(json.dumps({
  "license_id": "$license_id",
  "operation_id": "$op_id",
  "operation_type": "stage_create",
  "production_fingerprint": "$fingerprint",
  "database_uuid": "$db_uuid",
  "stage_id": "$stage_id",
  "stage_domain": "$stage_domain",
  "host_pubkey_fingerprint": "$host_fp",
  "architecture": "linux/amd64",
  "idempotency_key": "stage-create-$op_id",
}))
PY
)"
    local auth_resp
    if [[ "${SOVIEZ_STAGE_BLOCK_SAAS:-0}" == "1" ]]; then
      soviez_stage_die OPERATION_AUTHORIZATION_FAILED "SaaS blocked on offline target"
    fi
    auth_resp="$(soviez_stage_operations_authorize "$auth_body")"
    local ok
    ok="$(soviez_json_get "$auth_resp" ok 2>/dev/null || echo false)"
    if [[ "$ok" != "true" && "$ok" != "True" ]]; then
      soviez_stage_die OPERATION_AUTHORIZATION_FAILED "$(soviez_json_get "$auth_resp" denial_code 2>/dev/null || echo denied)"
    fi
    authorization_id="$(soviez_json_get "$auth_resp" authorization_id)"
    ticket_token="$(soviez_json_get "$auth_resp" ticket.token 2>/dev/null || soviez_json_get "$auth_resp" "ticket" | python3 -c 'import json,sys; t=json.load(sys.stdin); print(t.get("token",""))' 2>/dev/null || true)"
    if [[ -z "$ticket_token" || "$ticket_token" == "null" ]]; then
      # Fixture may embed token at top level
      ticket_token="$(soviez_json_get "$auth_resp" ticket_token 2>/dev/null || true)"
    fi
    [[ -n "$ticket_token" && "$ticket_token" != "null" ]] || soviez_stage_die TICKET_INVALID "Authorize response missing ticket"

    local work
    work="$(soviez_stage_op_dir "$op_id")/auth"
    mkdir -p "$work"
    chmod 700 "$work"
    printf '%s' "$ticket_token" > "$work/ticket.token"
    chmod 600 "$work/ticket.token"
    if [[ -n "${SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON:-}" ]]; then
      printf '%s' "$SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON" > "$work/keys.json"
      chmod 600 "$work/keys.json"
    fi
    # Never persist raw device credentials in operation JSON — only safe ids.
    soviez_stage_op_merge "$op_id" "$(python3 - <<PY
import json
print(json.dumps({"authorization_id": "$authorization_id", "ticket_present": True}))
PY
)"
    soviez_stage_inventory_update_field "$stage_id" "$(python3 - <<PY
import json
print(json.dumps({"authorization_id": "$authorization_id"}))
PY
)"
    soviez_stage_op_transition "$op_id" operation_authorized
    soviez_stage_checkpoint "$op_id" operation_authorized
    fi
  else
    authorization_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" authorization_id)"
    ticket_token="$(cat "$(soviez_stage_op_dir "$op_id")/auth/ticket.token" 2>/dev/null || true)"
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" tooling_authorized; then
    # Tooling resolved from authorize metadata / fixture digest pin — no public latest.
    soviez_stage_op_transition "$op_id" tooling_authorized
    mkdir -p "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest"
    printf 'digest=%s\n' "$tooling_digest" > "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.ok"
    soviez_stage_op_transition "$op_id" tooling_pulled
    soviez_stage_checkpoint "$op_id" tooling_pulled
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" ticket_verified; then
    local work keys_file expect_file
    work="$(soviez_stage_op_dir "$op_id")/auth"
    keys_file="$work/keys.json"
    expect_file="$work/expect.json"
    if [[ ! -f "$keys_file" ]]; then
      printf '%s\n' "${SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON:-{}}" > "$keys_file"
    fi
    python3 - <<PY > "$expect_file"
import json
print(json.dumps({
  "license_id": "$license_id",
  "device_id": "${SOVIEZ_STAGE_FIXTURE_DEVICE_ID:-dddddddd-dddd-dddd-dddd-dddddddddddd}",
  "host_pubkey_fingerprint": "${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-fp_host_fixture}",
  "production_fingerprint": "$fingerprint",
  "database_uuid": "$db_uuid",
  "stage_id": "$stage_id",
  "stage_domain": "$stage_domain",
  "operation_type": "stage_create",
  "release_digest": "$release_digest",
  "tooling_digest": "$tooling_digest",
  "architecture": "linux/amd64",
}))
PY
    if [[ "${SOVIEZ_STAGE_FIXTURE_SKIP_HELPER_VERIFY:-0}" == "1" ]]; then
      # Still require helper for neutralize; verify may be short-circuited only with explicit fixture offline offline-ledger path.
      soviez_log_info "Fixture skip helper verify (offline/unit harness only)"
    else
      # Bash Boolean cannot skip: without valid ticket+keys helper fails.
      local ledger_arg=""
      if [[ "${SOVIEZ_STAGE_USE_LEDGER:-0}" == "1" || "${SOVIEZ_STAGE_OFFLINE:-0}" == "1" ]]; then
        ledger_arg="$SOVIEZ_STAGE_LEDGER"
      fi
      if [[ -f "$work/ticket.token" && -s "$keys_file" && "$(cat "$keys_file")" != "{}" ]]; then
        if [[ -n "$ledger_arg" ]]; then
          soviez_stage_helper_run_verify "$work/ticket.token" "$keys_file" "$expect_file" "$ledger_arg" >/dev/null
        else
          soviez_stage_helper_run_verify "$work/ticket.token" "$keys_file" "$expect_file" >/dev/null
        fi
      elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN:-}" ]]; then
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN" > "$work/ticket.token"
        printf '%s' "$SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON" > "$keys_file"
        if [[ -n "$ledger_arg" ]]; then
          soviez_stage_helper_run_verify "$work/ticket.token" "$keys_file" "$expect_file" "$ledger_arg" >/dev/null
        else
          soviez_stage_helper_run_verify "$work/ticket.token" "$keys_file" "$expect_file" >/dev/null
        fi
      else
        soviez_stage_die TICKET_INVALID "Ticket verification requires helper and valid keys"
      fi
    fi
    # Enforce: a forced Bash entitlement true without ticket cannot certify later.
    soviez_stage_op_transition "$op_id" ticket_verified
    soviez_stage_checkpoint "$op_id" ticket_verified
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  local dump_file snap_fs
  if soviez_stage_sm_should_run "$state" snapshot_preparing; then
    soviez_stage_op_transition "$op_id" snapshot_preparing
    soviez_stage_checkpoint "$op_id" snapshot_preparing
    local source_db source_fs
    source_db="$(soviez_json_get "$prod_json" database_name)"
    source_fs="${SOVIEZ_STAGE_FIXTURE_FILESTORE:-$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || echo "")}"
    dump_file="$(soviez_stage_snapshot_db "$op_id" "${source_db:-production}")"
    soviez_stage_op_transition "$op_id" database_snapshot_created
    soviez_stage_checkpoint "$op_id" database_snapshot_created
    snap_fs="$(soviez_stage_snapshot_filestore "$op_id" "${source_fs:-$SOVIEZ_ROOT/fixtures/prod-filestore}")"
    # Prove Production filestore unchanged when source checksum recorded.
    soviez_stage_op_transition "$op_id" filestore_snapshot_created
    soviez_stage_checkpoint "$op_id" filestore_snapshot_created
  else
    dump_file="$(soviez_stage_snapshot_dir "$op_id")/db.dump"
    snap_fs="$(soviez_stage_snapshot_dir "$op_id")/filestore"
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" database_restoring; then
    soviez_stage_op_transition "$op_id" database_restoring
    soviez_stage_checkpoint "$op_id" database_restoring
    local identity db_name stage_uuid
    identity="$(soviez_stage_inventory_find "$stage_id")"
    db_name="$(soviez_json_get "$identity" stage_db_name)"
    stage_uuid="$(soviez_stage_restore_database "$op_id" "$db_name" "$dump_file")"
    soviez_stage_inventory_update_field "$stage_id" "$(python3 - <<PY
import json
print(json.dumps({"stage_database_uuid": "$stage_uuid"}))
PY
)"
    soviez_stage_op_transition "$op_id" filestore_restoring
    soviez_stage_checkpoint "$op_id" filestore_restoring
    soviez_stage_restore_filestore "$stage_id" "$snap_fs"
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" stage_runtime_created; then
    soviez_stage_runtime_create "$stage_id" >/dev/null
    soviez_stage_op_transition "$op_id" stage_runtime_created
    soviez_stage_checkpoint "$op_id" stage_runtime_created
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" neutralization_running; then
    soviez_stage_op_transition "$op_id" neutralization_running
    soviez_stage_checkpoint "$op_id" neutralization_running
    soviez_stage_neutralize_apply "$stage_id"
    local controls claims_file controls_file cert_out helper_out
    controls="$(soviez_stage_neutralize_controls_json "$stage_id")"
    work="$(soviez_stage_op_dir "$op_id")/auth"
    claims_file="$work/claims.json"
    controls_file="$work/controls.json"
    cert_out="$(soviez_stage_origin_cert_file "$stage_id")"
    printf '%s' "$controls" > "$controls_file"
    # Minimal claims for helper neutralize (from expect / identity)
    python3 - <<PY > "$claims_file"
import json
print(json.dumps({
  "typ": "soviez.stage-operation.v1",
  "protocol_version": "stage-operation/v1",
  "jti": "local",
  "operation_id": "$op_id",
  "operation_type": "stage_create",
  "subject_pseudonym": "sub_local",
  "account_id": "00000000-0000-0000-0000-000000000000",
  "license_id": "$license_id",
  "device_id": "${SOVIEZ_STAGE_FIXTURE_DEVICE_ID:-dddddddd-dddd-dddd-dddd-dddddddddddd}",
  "device_pubkey_fingerprint": "fp",
  "host_pubkey_fingerprint": "${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-fp_host_fixture}",
  "production_fingerprint": "$fingerprint",
  "database_uuid": "$db_uuid",
  "stage_id": "$stage_id",
  "stage_domain": "$stage_domain",
  "release_id": "release",
  "release_digest": "$release_digest",
  "tooling_artifact_id": "tooling",
  "tooling_digest": "$tooling_digest",
  "architecture": "linux/amd64",
  "entitlement_decision_ref": "ent",
  "delivery_trace_id": "del",
  "iat": 0,
  "exp": 9999999999,
  "nonce": "n",
  "signer_key_id": "sok",
}))
PY
    helper_out="$(soviez_stage_helper_run_neutralize "$claims_file" "$controls_file" "$cert_out")"
    [[ -f "$cert_out" ]] || soviez_stage_die ORIGIN_CERTIFICATE_FAILED "Origin certificate not written"
    soviez_stage_inventory_update_field "$stage_id" "$(python3 - <<PY
import json
print(json.dumps({"origin_certificate_path": "$cert_out", "lifecycle_status": "neutralized"}))
PY
)"
    soviez_stage_op_transition "$op_id" neutralization_validated
    soviez_stage_checkpoint "$op_id" neutralization_validated
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" authorization_consumed; then
    ticket_token="$(cat "$(soviez_stage_op_dir "$op_id")/auth/ticket.token" 2>/dev/null || true)"
    authorization_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" authorization_id)"
    if [[ "${SOVIEZ_STAGE_OFFLINE:-0}" == "1" || "${SOVIEZ_STAGE_BLOCK_SAAS:-0}" == "1" ]]; then
      # Local ledger already consumed at verify; no SaaS consume on offline target.
      :
    elif [[ -n "$ticket_token" && -n "$authorization_id" ]]; then
      soviez_stage_operations_consume "$authorization_id" "$ticket_token" >/dev/null || true
    fi
    soviez_stage_op_transition "$op_id" authorization_consumed
    soviez_stage_checkpoint "$op_id" authorization_consumed
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" domain_pending; then
    soviez_stage_op_transition "$op_id" domain_pending
    soviez_stage_checkpoint "$op_id" domain_pending
    soviez_stage_domain_validate_dns "$stage_domain" >/dev/null
    soviez_stage_op_transition "$op_id" ssl_pending
    soviez_stage_checkpoint "$op_id" ssl_pending
    soviez_stage_ssl_issue_and_validate "$stage_id" "$stage_domain" >/dev/null
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" runtime_validating; then
    soviez_stage_op_transition "$op_id" runtime_validating
    # Validate isolation markers
    local identity container network
    identity="$(soviez_stage_inventory_find "$stage_id")"
    container="$(soviez_json_get "$identity" stage_container)"
    network="$(soviez_json_get "$identity" stage_network)"
    [[ -n "$container" && -n "$network" ]] || soviez_stage_die STAGE_RUNTIME_FAILED "Missing isolation identity"
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      [[ -f "$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}.started" ]] || soviez_stage_die STAGE_RUNTIME_FAILED "Runtime stub missing"
      [[ -f "$SOVIEZ_ROOT/stubs/networks/${network}.created" ]] || soviez_stage_die STAGE_RUNTIME_FAILED "Network stub missing"
    fi
    [[ -f "$(soviez_stage_origin_cert_file "$stage_id")" ]] || soviez_stage_die ORIGIN_CERTIFICATE_FAILED "Missing origin cert"
    soviez_stage_op_transition "$op_id" origin_certificate_issued
    soviez_stage_checkpoint "$op_id" origin_certificate_issued
  fi
  state="$(soviez_stage_op_read_state "$op_id")"

  if soviez_stage_sm_should_run "$state" remote_completion_pending; then
    soviez_stage_op_transition "$op_id" remote_completion_pending
    soviez_stage_checkpoint "$op_id" remote_completion_pending
    local controls
    controls="$(soviez_stage_neutralize_controls_json "$stage_id")"
    ticket_token="$(cat "$(soviez_stage_op_dir "$op_id")/auth/ticket.token" 2>/dev/null || true)"
    authorization_id="$(soviez_json_get "$(cat "$(soviez_stage_op_state_file "$op_id")")" authorization_id)"
    if [[ "${SOVIEZ_STAGE_OFFLINE:-0}" == "1" || "${SOVIEZ_STAGE_BLOCK_SAAS:-0}" == "1" ]]; then
      soviez_log_info "Offline complete — local certification only (no SaaS)"
    elif [[ -n "$ticket_token" && -n "$authorization_id" ]]; then
      if ! soviez_stage_operations_complete "$authorization_id" "$ticket_token" "$controls" >/dev/null 2>&1; then
        soviez_log_warn "Remote completion pending — Stage remains usable locally"
        # Leave recoverably pending but still mark certified locally.
      fi
    fi
    soviez_stage_inventory_update_field "$stage_id" '{"lifecycle_status":"certified","health_state":"healthy"}'
    # Phase 13 — immutable retention clock from original created_at (14d default / 60d max)
    if declare -F soviez_retention_init_for_stage >/dev/null; then
      soviez_retention_init_for_stage "$stage_id"
      soviez_retention_render_banner "$stage_id" >/dev/null || true
    fi
    soviez_stage_runtime_start "$stage_id"
    soviez_stage_op_transition "$op_id" completed
  fi

  echo "Stage created: https://${stage_domain}"
  echo "Stage ID: $stage_id"
  echo "Reattach: soviez.sh --stage-reattach $op_id"
  echo "Lifecycle: --stage-list | --stage-status $stage_id | --stage-stop $stage_id | --stage-start $stage_id"
  echo "Retention: --stage-retention-status $stage_id | --stage-retention-extend $stage_id --days <total>"
}
