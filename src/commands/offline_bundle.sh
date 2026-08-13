# shellcheck shell=bash

soviez_cmd_offline_bundle_inspect() {
  local path="${SOVIEZ_CLI_OFFLINE_BUNDLE_PATH:-}"
  [[ -n "$path" ]] || soviez_offline_die OFFLINE_BUNDLE_REQUIRED "bundle path required"
  [[ -f "$path" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_FOUND "$path"
  soviez_offline_bundle_inspect "$path"
}

soviez_cmd_offline_bundle_import() {
  local path="${SOVIEZ_CLI_OFFLINE_BUNDLE_PATH:-}"
  local license_id="${SOVIEZ_LICENSE_ID:-${SOVIEZ_CLI_LICENSE_ID:-}}"
  local env_id="${SOVIEZ_ENVIRONMENT_ID:-${SOVIEZ_CLI_ENVIRONMENT_ID:-}}"
  local device_fp="${SOVIEZ_DEVICE_FINGERPRINT:-${SOVIEZ_CLI_DEVICE_FINGERPRINT:-}}"
  [[ -n "$path" && -n "$license_id" && -n "$env_id" && -n "$device_fp" ]] \
    || soviez_offline_die OFFLINE_BUNDLE_REQUIRED "bundle + license + environment + device required"
  soviez_offline_bundle_import "$path" "$license_id" "$env_id" "$device_fp" "${SOVIEZ_CURRENT_ERP_DIGEST:-}"
}

soviez_cmd_offline_bundle_plan() {
  local path="${SOVIEZ_CLI_OFFLINE_BUNDLE_PATH:-}"
  [[ -n "$path" ]] || soviez_offline_die OFFLINE_BUNDLE_REQUIRED "bundle path or id required"
  export SOVIEZ_LICENSE_ID="${SOVIEZ_LICENSE_ID:-${SOVIEZ_CLI_LICENSE_ID:?}}"
  export SOVIEZ_ENVIRONMENT_ID="${SOVIEZ_ENVIRONMENT_ID:-${SOVIEZ_CLI_ENVIRONMENT_ID:?}}"
  export SOVIEZ_DEVICE_FINGERPRINT="${SOVIEZ_DEVICE_FINGERPRINT:-${SOVIEZ_CLI_DEVICE_FINGERPRINT:?}}"
  soviez_offline_update_plan "$path"
}

soviez_cmd_offline_update_apply() {
  local path="${SOVIEZ_CLI_OFFLINE_BUNDLE_PATH:-}"
  [[ -n "$path" ]] || soviez_offline_die OFFLINE_BUNDLE_REQUIRED "bundle path or id required"
  export SOVIEZ_LICENSE_ID="${SOVIEZ_LICENSE_ID:-${SOVIEZ_CLI_LICENSE_ID:?}}"
  export SOVIEZ_ENVIRONMENT_ID="${SOVIEZ_ENVIRONMENT_ID:-${SOVIEZ_CLI_ENVIRONMENT_ID:?}}"
  export SOVIEZ_DEVICE_FINGERPRINT="${SOVIEZ_DEVICE_FINGERPRINT:-${SOVIEZ_CLI_DEVICE_FINGERPRINT:?}}"
  if [[ -n "${SOVIEZ_CLI_CONFIRM_TEXT:-}" ]]; then
    export SOVIEZ_OFFLINE_APPLY_CONFIRM="$SOVIEZ_CLI_CONFIRM_TEXT"
  fi
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && export SOVIEZ_OFFLINE_APPLY_YES=1
  soviez_offline_update_apply "$path"
}

soviez_cmd_offline_update_status() {
  soviez_offline_update_status "${SOVIEZ_CLI_OP_ID:?}"
}

soviez_cmd_offline_update_result_export() {
  soviez_offline_update_result_export "${SOVIEZ_CLI_OP_ID:?}" "${SOVIEZ_CLI_RESULT_OUT:-}"
}

soviez_cmd_offline_update_result_show() {
  soviez_offline_update_result_show "${SOVIEZ_CLI_OFFLINE_RECEIPT_PATH:?}"
}

soviez_cmd_offline_trust_inspect() {
  local path="${SOVIEZ_CLI_OFFLINE_TRUST_PATH:?}"
  [[ -f "$path" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_FOUND "$path"
  if [[ -f "${path}.sig" ]] || grep -q signature_b64url "$path" 2>/dev/null; then
    soviez_offline_trust_verify_json_file trust_root "$path" || \
      soviez_offline_die OFFLINE_BUNDLE_SIGNATURE_INVALID "trust package"
  fi
  cat "$path"
}

soviez_cmd_offline_trust_import() {
  local path="${SOVIEZ_CLI_OFFLINE_TRUST_PATH:?}"
  soviez_offline_trust_paths_init
  soviez_offline_trust_verify_json_file trust_root "$path" || \
    soviez_offline_die OFFLINE_BUNDLE_SIGNATURE_INVALID "trust package"
  local seq local_seq
  seq="$(soviez_json_get "$(cat "$path")" sequence 2>/dev/null || echo 0)"
  soviez_offline_trust_state_init
  local_seq="$(soviez_json_get "$(cat "$SOVIEZ_OFFLINE_TRUST_STATE")" sequence 2>/dev/null || echo 0)"
  if [[ "${seq:-0}" -lt "${local_seq:-0}" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_TRUST_STATE_ROLLBACK "Trust sequence rollback denied"
  fi
  cp -p "$path" "$SOVIEZ_OFFLINE_TRUST_DIR/imported_roots.json"
  SOVIEZ_S="$SOVIEZ_OFFLINE_TRUST_STATE" SOVIEZ_SEQ="$seq" python3 - <<'PY'
import json,os
p=os.environ["SOVIEZ_S"]
d=json.load(open(p))
d["sequence"]=int(os.environ["SOVIEZ_SEQ"])
open(p,"w").write(json.dumps(d,separators=(",",":")))
PY
  soviez_offline_trust_record_time
  echo "TRUST PACKAGE — IMPORTED sequence=$seq"
}

soviez_cmd_offline_phase24_readiness() {
  soviez_offline_phase24_readiness
}
