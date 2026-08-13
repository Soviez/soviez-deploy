# shellcheck shell=bash
# inventory.sh — thin aggregator for image status CLI

soviez_image_inventory_report() {
  local production_id="${1:-}"
  soviez_image_status "$production_id"
}
