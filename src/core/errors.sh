# shellcheck shell=bash

SOVIEZ_ERR_GENERIC=1
SOVIEZ_ERR_USAGE=2
SOVIEZ_ERR_PREFLIGHT=3
SOVIEZ_ERR_STATE=4
SOVIEZ_ERR_API=5
SOVIEZ_ERR_AUTH=6
SOVIEZ_ERR_SSL=7
SOVIEZ_ERR_LICENSE=8
SOVIEZ_ERR_TERMINAL=9

soviez_die() {
  local code="${1:-$SOVIEZ_ERR_GENERIC}"
  shift || true
  if [[ $# -gt 0 ]]; then
    soviez_log_error "$*"
  fi
  exit "$code"
}

soviez_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    soviez_die "$SOVIEZ_ERR_PREFLIGHT" "Required command not found: $cmd"
  fi
}
