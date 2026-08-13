# shellcheck shell=bash

# Shared systemd worker contract. Command engines retain their proven unit
# renderers; this module standardizes naming, env hygiene, and cleanup policy.

soviez_ops_systemd_unit_name() {
  local op_id="$1"
  op_id="$(printf '%s' "$op_id" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')"
  printf 'soviez-op-%s.service\n' "$op_id"
}

soviez_ops_systemd_env_file() {
  printf '%s/worker.env\n' "$(soviez_ops_resolve_dir "$1")"
}

# Write a restricted EnvironmentFile: never secrets, only operation identity paths.
soviez_ops_systemd_write_env() {
  local op_id="$1" path
  path="$(soviez_ops_systemd_env_file "$op_id")"
  cat > "$path" <<EOF
SOVIEZ_OPERATION_ID=$op_id
SOVIEZ_OPS_CANONICAL=$(soviez_ops_canonical_state_path "$op_id")
SOVIEZ_OPS_ROOT=$SOVIEZ_OPS_ROOT
EOF
  chmod 600 "$path"
}

soviez_ops_systemd_cleanup_terminal() {
  local op_id="$1" unit
  unit="$(soviez_ops_systemd_unit_name "$op_id")"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop "$unit" 2>/dev/null || true
    systemctl disable "$unit" 2>/dev/null || true
    rm -f "/etc/systemd/system/$unit" 2>/dev/null || true
  fi
}
