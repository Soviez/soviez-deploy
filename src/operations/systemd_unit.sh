# shellcheck shell=bash

soviez_systemd_unit_path() {
  local op_id="$1"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf '%s/systemd/soviez-worker-%s.service\n' "$SOVIEZ_ROOT" "$op_id"
  else
    printf '/etc/systemd/system/soviez-worker-%s.service\n' "$op_id"
  fi
}

soviez_systemd_render_unit() {
  local op_id="$1"
  local script_path="$2"
  cat <<EOF
[Unit]
Description=Soviez installer worker ${op_id}
After=network.target

[Service]
Type=simple
ExecStart=${script_path} ${op_id}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

soviez_systemd_start_worker() {
  local op_id="$1"
  local worker_script="$2"
  local unit
  unit="$(soviez_systemd_unit_path "$op_id")"
  mkdir -p "$(dirname "$unit")"
  soviez_systemd_render_unit "$op_id" "$worker_script" > "$unit"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    (
      while true; do
        soviez_op_heartbeat "$op_id"
        sleep 1
      done
    ) &
    echo $! > "$SOVIEZ_ROOT/systemd/worker-${op_id}.pid"
    return 0
  fi

  systemctl daemon-reload
  systemctl enable --now "soviez-worker-${op_id}.service"
}

soviez_systemd_reattach() {
  local op_id="$1"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    [[ -f "$(soviez_operation_heartbeat_file "$op_id")" ]]
    return $?
  fi
  systemctl is-active --quiet "soviez-worker-${op_id}.service"
}
