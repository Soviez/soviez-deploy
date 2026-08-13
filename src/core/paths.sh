# shellcheck shell=bash

soviez_paths_init() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    if [[ -z "${SOVIEZ_ROOT:-}" ]]; then
      SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-test.XXXXXX")"
      export SOVIEZ_ROOT
    fi
    # Force derive ops roots from SOVIEZ_ROOT (ignore inherited pollution).
    SOVIEZ_OPS_ROOT="$SOVIEZ_ROOT/ops"
    SOVIEZ_DEVICE_DIR="$SOVIEZ_ROOT/device"
    SOVIEZ_SECRETS_DIR="$SOVIEZ_ROOT/secrets"
    SOVIEZ_TENANT_DIR="$SOVIEZ_ROOT/tenant"
    SOVIEZ_SAAS_BASE_URL="${SOVIEZ_SAAS_BASE_URL:-http://127.0.0.1:8765}"
    SOVIEZ_REGISTRY_GATEWAY_URL="${SOVIEZ_REGISTRY_GATEWAY_URL:-http://127.0.0.1:8766}"
  else
    SOVIEZ_OPS_ROOT="${SOVIEZ_OPS_ROOT:-/var/soviez/ops}"
    SOVIEZ_DEVICE_DIR="${SOVIEZ_DEVICE_DIR:-/etc/soviez/device}"
    SOVIEZ_SECRETS_DIR="${SOVIEZ_SECRETS_DIR:-/etc/soviez/secrets}"
    SOVIEZ_TENANT_DIR="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}"
    SOVIEZ_SAAS_BASE_URL="${SOVIEZ_SAAS_BASE_URL:-https://app.soviez.com}"
    SOVIEZ_REGISTRY_GATEWAY_URL="${SOVIEZ_REGISTRY_GATEWAY_URL:-https://registry.soviez.com}"
  fi

  export SOVIEZ_OPS_ROOT SOVIEZ_DEVICE_DIR SOVIEZ_SECRETS_DIR SOVIEZ_TENANT_DIR
  export SOVIEZ_SAAS_BASE_URL SOVIEZ_REGISTRY_GATEWAY_URL

  mkdir -p "$SOVIEZ_OPS_ROOT/operations" "$SOVIEZ_DEVICE_DIR" "$SOVIEZ_SECRETS_DIR" "$SOVIEZ_TENANT_DIR"
  if declare -F soviez_stage_paths_init >/dev/null 2>&1; then
    soviez_stage_paths_init
  fi
  if declare -F soviez_ssl_paths_init >/dev/null 2>&1; then
    soviez_ssl_paths_init
  fi
}

soviez_operation_dir() {
  local op_id="$1"
  printf '%s/operations/%s\n' "$SOVIEZ_OPS_ROOT" "$op_id"
}

soviez_operation_state_file() {
  printf '%s/state.json\n' "$(soviez_operation_dir "$1")"
}

soviez_operation_events_file() {
  printf '%s/events.jsonl\n' "$(soviez_operation_dir "$1")"
}

soviez_operation_lock_file() {
  printf '%s/lock\n' "$(soviez_operation_dir "$1")"
}

soviez_operation_heartbeat_file() {
  printf '%s/heartbeat\n' "$(soviez_operation_dir "$1")"
}
