# shellcheck shell=bash

soviez_backup_compression_level() {
  # profile → zstd/gzip level
  local profile="${1:-balanced}"
  case "$profile" in
    conservative|slow) printf '10\n' ;;
    fast) printf '1\n' ;;
    balanced|*) printf '3\n' ;;
  esac
}

soviez_backup_resource_nice() {
  local profile="${1:-balanced}"
  case "$profile" in
    conservative) printf '15\n' ;;
    fast) printf '0\n' ;;
    balanced|*) printf '10\n' ;;
  esac
}
