# shellcheck shell=bash

soviez_ops_print_status() {
  local op_id="$1" record path
  path="$(soviez_ops_canonical_state_path "$op_id")"
  if [[ -f "$path" ]]; then record="$(cat "$path")"
  else record="$(soviez_ops_registry_get "$op_id")"
  fi
  if [[ "${SOVIEZ_OPS_JSON:-0}" == "1" ]]; then printf '%s\n' "$record"
  else
    printf 'Operation: %s\nType: %s\nEnvironment: %s\nState: %s\nCheckpoint: %s\nUpdated: %s\nHeartbeat: %s\nLog: %s\n' \
      "$(soviez_json_get "$record" operation_id)" "$(soviez_json_get "$record" operation_type)" \
      "$(soviez_json_get "$record" environment_id)" "$(soviez_json_get "$record" current_state)" \
      "$(soviez_json_get "$record" current_checkpoint)" "$(soviez_json_get "$record" updated_at)" \
      "$(soviez_json_get "$record" heartbeat_at)" "$(soviez_ops_log_path "$op_id" 2>/dev/null || true)"
  fi
}
