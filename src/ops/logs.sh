# shellcheck shell=bash

soviez_ops_log_path() { printf '%s/operation.log\n' "$(soviez_ops_resolve_dir "$1")"; }
soviez_ops_log_append() {
  local op_id="$1"; shift
  local path; path="$(soviez_ops_log_path "$op_id")"; mkdir -p "$(dirname "$path")"
  printf '%s %s\n' "$(soviez_ops_now_utc)" "$(soviez_redact_text "$*")" >> "$path"; chmod 600 "$path"
}
soviez_ops_log_tail() {
  local op_id="$1" n="${2:-50}" path; path="$(soviez_ops_log_path "$op_id")"
  [[ -f "$path" ]] && tail -n "$n" "$path"
}
