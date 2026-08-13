# shellcheck shell=bash
# reporting.sh — human/JSON reporting helpers

soviez_image_report_print() {
  local json="$1"
  printf '%s\n' "$json"
}
