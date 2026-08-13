# shellcheck shell=bash
# Test-only pause/fault hooks for disconnect/resume certification.
# Production builds never sleep; hooks activate only when SOVIEZ_TEST_MODE=1
# and SOVIEZ_STAGE_PAUSE_AT / SOVIEZ_STAGE_FAULT_AT are set.

soviez_stage_checkpoint() {
  local op_id="$1"
  local state="$2"
  local hb
  hb="$(soviez_stage_op_dir "$op_id")/heartbeat"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$hb"
  chmod 600 "$hb" 2>/dev/null || true

  if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    return 0
  fi

  local mark
  mark="$(soviez_stage_op_dir "$op_id")/checkpoint_${state}"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$mark"

  if [[ -n "${SOVIEZ_STAGE_FAULT_AT:-}" && "${SOVIEZ_STAGE_FAULT_AT}" == "$state" ]]; then
    soviez_stage_op_transition "$op_id" failed_retryable '{"fault":"injected"}' 2>/dev/null || true
    soviez_stage_die RECOVERY_REQUIRED "Injected fault at $state"
  fi

  if [[ -n "${SOVIEZ_STAGE_PAUSE_AT:-}" && "${SOVIEZ_STAGE_PAUSE_AT}" == "$state" ]]; then
    local pause_file resume_file
    pause_file="$(soviez_stage_op_dir "$op_id")/paused"
    resume_file="$(soviez_stage_op_dir "$op_id")/resume"
    rm -f "$resume_file"
    printf '%s\n' "$state" > "$pause_file"
    chmod 600 "$pause_file"
    soviez_log_info "Paused at $state (test hook); waiting for resume file"
    local waited=0
    local max_wait="${SOVIEZ_STAGE_PAUSE_MAX_SEC:-120}"
    while [[ ! -f "$resume_file" ]]; do
      sleep 0.2
      waited=$((waited + 1))
      if [[ $waited -gt $((max_wait * 5)) ]]; then
        soviez_stage_die RECOVERY_REQUIRED "Pause timeout at $state"
      fi
      # Allow controller kill: if SOVIEZ_STAGE_PAUSE_EXIT_CONTROLLER=1, exit process while paused.
      if [[ "${SOVIEZ_STAGE_PAUSE_EXIT_CONTROLLER:-0}" == "1" && -f "$(soviez_stage_op_dir "$op_id")/controller_exit" ]]; then
        soviez_log_info "Controller exit requested while paused at $state"
        exit 0
      fi
    done
    rm -f "$resume_file" "$pause_file"
    soviez_log_info "Resumed from pause at $state"
  fi
}

soviez_stage_worker_script_path() {
  local op_id="$1"
  printf '%s/worker.sh\n' "$(soviez_stage_op_dir "$op_id")"
}

soviez_stage_worker_pid_file() {
  local op_id="$1"
  printf '%s/worker.pid\n' "$(soviez_stage_op_dir "$op_id")"
}

soviez_stage_start_durable_worker() {
  # Start a durable Stage create worker that survives controller disconnect.
  local op_id="$1"
  local script_path installer unit
  script_path="$(soviez_stage_worker_script_path "$op_id")"
  installer="${SOVIEZ_STAGE_INSTALLER_PATH:-${SOVIEZ_SH_ROOT}/dist/soviez.sh}"
  mkdir -p "$(soviez_stage_op_dir "$op_id")"
  cat > "$script_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$installer"
ENVF="$(soviez_stage_op_dir "$op_id")/worker.env"
if [[ -f "\$ENVF" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "\$ENVF"
  set +a
fi
# Re-assert identity after sourcing modules (module tops reset CLI globals).
export SOVIEZ_TEST_MODE="\${SOVIEZ_TEST_MODE:-1}"
export SOVIEZ_CLI_COMMAND=stage
export SOVIEZ_CLI_OP_ID="$op_id"
export SOVIEZ_STAGE_WORKER_INNER=1
export SOVIEZ_STAGE_DURABLE_WORKER=0
soviez_paths_init
soviez_stage_paths_init
soviez_cmd_stage_create_run
EOF
  chmod 700 "$script_path"

  # Render systemd unit (test or real).
  unit="$(soviez_systemd_unit_path "$op_id")"
  mkdir -p "$(dirname "$unit")"
  soviez_systemd_render_unit "$op_id" "$script_path" > "$unit"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mkdir -p "$SOVIEZ_ROOT/systemd"
    nohup bash "$script_path" > "$(soviez_stage_op_dir "$op_id")/worker.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$(soviez_stage_worker_pid_file "$op_id")"
    echo "$pid" > "$SOVIEZ_ROOT/systemd/worker-${op_id}.pid"
    # Heartbeat companion
    (
      while kill -0 "$pid" 2>/dev/null; do
        date -u +%Y-%m-%dT%H:%M:%SZ > "$(soviez_stage_op_dir "$op_id")/heartbeat"
        sleep 1
      done
    ) &
    echo $! > "$SOVIEZ_ROOT/systemd/heartbeat-${op_id}.pid"
    return 0
  fi

  systemctl daemon-reload
  systemctl enable --now "soviez-worker-${op_id}.service"
}

soviez_stage_worker_alive() {
  local op_id="$1"
  local pf
  pf="$(soviez_stage_worker_pid_file "$op_id")"
  if [[ -f "$pf" ]]; then
    kill -0 "$(cat "$pf")" 2>/dev/null && return 0
  fi
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -f "$SOVIEZ_ROOT/systemd/worker-${op_id}.pid" ]]; then
    kill -0 "$(cat "$SOVIEZ_ROOT/systemd/worker-${op_id}.pid")" 2>/dev/null && return 0
  fi
  return 1
}
