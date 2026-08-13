# shellcheck shell=bash

SOVIEZ_SPINNER_PID=""

soviez_ui_spinner_start() {
  local msg="${1:-Working...}"
  if [[ ! -t 1 ]]; then
    soviez_log_info "$msg"
    return 0
  fi
  (
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while true; do
      printf '\r%s %s' "${frames[$i]}" "$msg"
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.1
    done
  ) &
  SOVIEZ_SPINNER_PID=$!
}

soviez_ui_spinner_stop() {
  if [[ -n "${SOVIEZ_SPINNER_PID:-}" ]]; then
    kill "$SOVIEZ_SPINNER_PID" 2>/dev/null || true
    wait "$SOVIEZ_SPINNER_PID" 2>/dev/null || true
    SOVIEZ_SPINNER_PID=""
    printf '\r\033[K'
  fi
}

soviez_ui_dashboard_show() {
  local state="$1"
  soviez_log_info "Operation state: $state"
}
