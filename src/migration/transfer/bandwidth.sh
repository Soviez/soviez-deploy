# shellcheck shell=bash

soviez_migration_bandwidth_profile_delay() {
  local profile="${1:-balanced}"
  case "$profile" in
    conservative) sleep 0.05 ;;
    fast) : ;;
    balanced|*) sleep 0.01 ;;
  esac
}

soviez_migration_bandwidth_throttle_bytes() {
  local profile="${1:-balanced}" bytes="${2:-0}"
  # Stub throttle — sleep proportional to profile for large payloads in non-fast mode
  case "$profile" in
    conservative)
      if [[ "$bytes" -gt 1048576 ]]; then sleep 0.1; fi
      ;;
    balanced)
      if [[ "$bytes" -gt 8388608 ]]; then sleep 0.02; fi
      ;;
    fast) : ;;
  esac
}
