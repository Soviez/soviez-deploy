# shellcheck shell=bash

soviez_license_choose_activation_method() {
  local requested="${1:-automatic}"
  case "$requested" in
    automatic|manual) printf '%s' "$requested" ;;
    *) soviez_die "$SOVIEZ_ERR_LICENSE" "Invalid activation method: $requested" ;;
  esac
}
