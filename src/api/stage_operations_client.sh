# shellcheck shell=bash
# SaaS Stage Operation + entitlement clients (Device PoP).

soviez_stage_entitlement_check() {
  local license_id="$1"
  local operation="${2:-stage_create}"
  local body
  body="$(SOVIEZ_LIC="$license_id" SOVIEZ_OP="$operation" python3 - <<'PY'
import json,os
print(json.dumps({"license_id": os.environ["SOVIEZ_LIC"], "operation": os.environ["SOVIEZ_OP"]}))
PY
)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON"
    return 0
  fi
  soviez_http_signed_post_json "/api/installer/entitlements/stage/check" "$body"
}

soviez_stage_operations_authorize() {
  local body="$1"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_STAGE_FIXTURE_AUTHORIZE_JSON"
    return 0
  fi
  soviez_http_signed_post_json "/api/installer/stage/operations/authorize" "$body"
}

soviez_stage_operations_consume() {
  local authorization_id="$1"
  local ticket_token="$2"
  local body
  body="$(SOVIEZ_A="$authorization_id" SOVIEZ_T="$ticket_token" python3 - <<'PY'
import json,os
print(json.dumps({"authorization_id": os.environ["SOVIEZ_A"], "ticket_token": os.environ["SOVIEZ_T"]}))
PY
)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE:-0}" == "1" ]]; then
    printf '{"ok":true,"status":"consumed","idempotent":false}\n'
    return 0
  fi
  soviez_http_signed_post_json "/api/installer/stage/operations/consume" "$body"
}

soviez_stage_operations_complete() {
  local authorization_id="$1"
  local ticket_token="$2"
  local neutralization_json="$3"
  local body
  body="$(SOVIEZ_A="$authorization_id" SOVIEZ_T="$ticket_token" SOVIEZ_N="$neutralization_json" python3 - <<'PY'
import json,os
print(json.dumps({
  "authorization_id": os.environ["SOVIEZ_A"],
  "ticket_token": os.environ["SOVIEZ_T"],
  "neutralization": json.loads(os.environ["SOVIEZ_N"]),
}))
PY
)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE:-0}" == "1" ]]; then
    printf '{"ok":true,"status":"completed","phone_home":false}\n'
    return 0
  fi
  soviez_http_signed_post_json "/api/installer/stage/operations/complete" "$body"
}

soviez_stage_operations_revoke() {
  local authorization_id="$1"
  local body
  body="$(SOVIEZ_A="$authorization_id" python3 - <<'PY'
import json,os
print(json.dumps({"authorization_id": os.environ["SOVIEZ_A"], "reason": "canceled_before_create"}))
PY
)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE:-0}" == "1" ]]; then
    printf '{"ok":true,"status":"revoked"}\n'
    return 0
  fi
  soviez_http_signed_post_json "/api/installer/stage/operations/revoke" "$body"
}
