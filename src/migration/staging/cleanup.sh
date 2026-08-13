# shellcheck shell=bash

soviez_migration_staging_cleanup() {
  local staging_id="$1" confirm="${2:-0}"
  [[ "$confirm" == "1" ]] || soviez_migration_die MIGRATION_CONFIRMATION_REQUIRED "Staging delete requires confirm"
  local dir
  dir="$(soviez_migration_staging_dir "$staging_id")"
  [[ -d "$dir" ]] || { printf '{"status":"already_absent"}\n'; return 0; }
  # Exact ownership: only delete if identity.json present with this staging_id
  if [[ -f "$dir/identity.json" ]]; then
    local sid
    sid="$(soviez_json_get "$(cat "$dir/identity.json")" staging_id)"
    [[ "$sid" == "$staging_id" ]] || soviez_migration_die MIGRATION_DESTINATION_CLEANUP_REQUIRED "Ownership mismatch"
  fi
  # Exact Docker teardown for operation-owned disposable fixtures only.
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    local erp_cid pg_cid net
    erp_cid="$(cat "$dir/docker.erp" 2>/dev/null || true)"
    pg_cid="$(cat "$dir/docker.pg" 2>/dev/null || true)"
    net="$(cat "$dir/docker.network" 2>/dev/null || true)"
    if [[ -n "$erp_cid" && "$erp_cid" == soviez-p19-erp-* ]]; then
      docker rm -f "$erp_cid" >/dev/null 2>&1 || true
    fi
    if [[ -n "$pg_cid" && "$pg_cid" == soviez-p19-pg-* ]]; then
      docker rm -f "$pg_cid" >/dev/null 2>&1 || true
    elif [[ -n "$pg_cid" && -n "$net" ]]; then
      docker network disconnect -f "$net" "$pg_cid" >/dev/null 2>&1 || true
    fi
    if [[ -n "$net" && "$net" == soviez-p19-stg-* ]]; then
      docker network rm "$net" >/dev/null 2>&1 || true
    fi
  fi
  rm -rf "$dir"
  printf '{"staging_id":"%s","status":"deleted"}\n' "$staging_id"
}
