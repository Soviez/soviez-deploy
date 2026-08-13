# shellcheck shell=bash

soviez_docker_labels_for_operation() {
  local op_id="$1"
  printf 'soviez.operation_id=%s\nsoviez.managed=true\n' "$op_id"
}
