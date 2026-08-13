# shellcheck shell=bash

soviez_license_send_activation_ack() {
  local slot_id="$1"
  soviez_slots_activation_ack "$slot_id" >/dev/null
  soviez_log_info "Activation acknowledged to SaaS"
}
