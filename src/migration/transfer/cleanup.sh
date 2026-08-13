# shellcheck shell=bash

soviez_migration_transfer_cleanup() {
  local op_id="${1:-}" delete_staging="${2:-0}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  soviez_migration_paths_init
  local op_dir ch_dir chunks_dir staging_id
  op_dir="$(soviez_migration_transfer_op_dir "$op_id")"
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  chunks_dir="$(soviez_migration_transfer_chunks_dir "$op_id")"
  # Exact cleanup only — never broad rm
  if [[ -d "$ch_dir" ]]; then
    rm -f "$ch_dir"/inbox/*.chunk "$ch_dir"/inbox/*.sha256 2>/dev/null || true
    rm -f "$ch_dir"/outbox/* 2>/dev/null || true
  fi
  if [[ -d "$chunks_dir/payloads" ]]; then
    # Keep registry for diagnostics; remove only payload binaries for this op
    find "$chunks_dir/payloads" -type f -name '*.bin' -delete 2>/dev/null || true
  fi
  if [[ "$delete_staging" == "1" ]]; then
    staging_id="$(soviez_json_get "$(soviez_migration_transfer_state_read "$op_id" 2>/dev/null || echo '{}')" destination_staging_id 2>/dev/null || true)"
    if [[ -n "$staging_id" && "$staging_id" != "null" ]]; then
      local sdir
      sdir="$(soviez_migration_staging_dir "$staging_id")"
      # Ownership check: staging must reference this op
      if [[ -f "$sdir/identity.json" ]]; then
        local bound
        bound="$(soviez_json_get "$(cat "$sdir/identity.json")" operation_id)"
        if [[ "$bound" == "$op_id" ]]; then
          rm -rf "$sdir"
        fi
      fi
    fi
  fi
  soviez_migration_transfer_state_merge "$op_id" '{"cleanup_completed":true,"current_state":"cleaned"}' >/dev/null
  printf '{"operation_id":"%s","status":"cleaned","staging_deleted":%s}\n' \
    "$op_id" "$([[ "$delete_staging" == "1" ]] && echo true || echo false)"
}
