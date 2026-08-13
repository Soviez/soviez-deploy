# shellcheck shell=bash
# Phase 12 SSL CLI commands.

soviez_cmd_ssl_status() {
  local env_id="${1:-}"
  soviez_ssl_paths_init
  if [[ -z "$env_id" ]]; then
    local id
    local any=0
    for id in $(soviez_ssl_inventory_list_ids); do
      any=1
      soviez_ssl_monitor_apply "$id" >/dev/null || true
      soviez_ssl_format_status_line "$id"
    done
    (( any == 1 )) || printf 'No managed SSL environments\n'
    return 0
  fi
  soviez_ssl_monitor_apply "$env_id" >/dev/null || true
  soviez_ssl_format_status_line "$env_id"
}

soviez_cmd_ssl_renew() {
  local env_id="${1:-}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "--ssl-renew requires environment id"
  soviez_ssl_renew_run "$env_id" 1
}

soviez_cmd_ssl_repair() {
  local env_id="${1:-}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "--ssl-repair requires environment id"
  soviez_ssl_repair "$env_id"
}

soviez_cmd_ssl_reattach() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_RECOVERY_REQUIRED" "--ssl-reattach requires operation id"
  soviez_ssl_reattach "$op_id"
}

soviez_cmd_ssl_policy() {
  local env_id="${1:-}"
  local set_mode="${2:-}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "--ssl-policy requires environment id"
  if [[ -n "$set_mode" ]]; then
    set_mode="$(soviez_ssl_policy_normalize_mode "$set_mode")"
    soviez_ssl_inventory_patch "$env_id" "$(MODE="$set_mode" python3 - <<'PY'
import json, os
print(json.dumps({"renewal_mode": os.environ["MODE"]}))
PY
)"
    printf 'renewal_mode set to %s (existing certificate remains valid)\n' "$set_mode"
  fi
  local rec
  rec="$(soviez_ssl_inventory_read "$env_id")"
  printf 'env=%s renewal_mode=%s lead_days=%s provider=%s cert_mode=%s private_ca=%s wildcard_scope=%s\n' \
    "$env_id" \
    "$(soviez_json_get "$rec" renewal_mode)" \
    "$(soviez_json_get "$rec" renewal_lead_days)" \
    "$(soviez_json_get "$rec" acme_provider)" \
    "$(soviez_json_get "$rec" certificate_mode)" \
    "$(soviez_json_get "$rec" private_ca_policy)" \
    "$(soviez_json_get "$rec" wildcard_scope)"
}

soviez_cmd_ssl_try_again() {
  local env_id="${1:-}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "environment id required"
  soviez_ssl_try_again "$env_id"
}

soviez_cmd_ssl_abort() {
  local env_id="${1:-}"
  [[ -n "$env_id" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_ENVIRONMENT_SELECTION_REQUIRED" "environment id required"
  soviez_ssl_abort_safely "$env_id"
}
