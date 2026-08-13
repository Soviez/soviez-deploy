# shellcheck shell=bash

SOVIEZ_LOG_LEVEL="${SOVIEZ_LOG_LEVEL:-info}"
SOVIEZ_LOG_JSON="${SOVIEZ_LOG_JSON:-0}"

_soviez_log_level_num() {
  case "$(printf '%s' "${1:-info}" | tr '[:upper:]' '[:lower:]')" in
    debug) echo 10 ;;
    info) echo 20 ;;
    warn|warning) echo 30 ;;
    error) echo 40 ;;
    *) echo 20 ;;
  esac
}

_soviez_log_should() {
  local want="$1"
  local cur
  cur="$(_soviez_log_level_num "$SOVIEZ_LOG_LEVEL")"
  [[ "$want" -ge "$cur" ]]
}

_soviez_log_emit() {
  local level="$1"
  local msg="$2"
  local redacted
  redacted="$(soviez_redact_text "$msg")"
  if [[ "$SOVIEZ_LOG_JSON" == "1" ]]; then
    soviez_json_log_line "$level" "$redacted" >&2
  else
    printf '[%s] %s\n' "$level" "$redacted" >&2
  fi
}

soviez_log_debug() {
  if _soviez_log_should 10; then
    _soviez_log_emit debug "$*"
  fi
}

soviez_log_info() {
  if _soviez_log_should 20; then
    _soviez_log_emit info "$*"
  fi
}

soviez_log_warn() {
  if _soviez_log_should 30; then
    _soviez_log_emit warn "$*"
  fi
}

soviez_log_error() {
  if _soviez_log_should 40; then
    _soviez_log_emit error "$*"
  fi
}
