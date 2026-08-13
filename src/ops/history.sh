# shellcheck shell=bash

soviez_ops_history_append() {
  local op_id="$1" record; record="$(cat "$(soviez_ops_canonical_state_path "$op_id")")" || return 1
  printf '%s\n' "$record" >> "$(soviez_ops_history_path "$op_id")"; chmod 600 "$(soviez_ops_history_path "$op_id")"
}
soviez_ops_history_list() {
  local op_id="${1:-}" file
  if [[ -n "$op_id" ]]; then cat "$(soviez_ops_history_path "$op_id")" 2>/dev/null || true
  else for file in "$SOVIEZ_OPS_HISTORY_DIR"/*.jsonl; do [[ -f "$file" ]] && cat "$file"; done; fi
}
