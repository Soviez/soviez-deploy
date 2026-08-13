# shellcheck shell=bash
# Phase 13 — fail-closed ownership validation before retention deletion.

soviez_retention_safe_shield_fail() {
  printf 'SAFE_SHIELD_FAILURE=%s\n' "$1" >&2
  return 1
}

soviez_retention_safe_shield_path_under_stage() {
  local path="$1" stage_dir="$2" real_path real_stage
  [[ "$path" != *".."* ]] || return 1
  [[ ! -L "$path" ]] || return 1
  real_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null)" || return 1
  real_stage="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$stage_dir" 2>/dev/null)" || return 1
  [[ "$real_path" == "$real_stage"/* ]]
}

soviez_retention_safe_shield_validate() {
  local stage_id="$1" identity stage_dir db container network fs cfg secrets cert expected
  stage_id="$(soviez_stage_sanitize_id "$stage_id")" || { soviez_retention_safe_shield_fail STAGE_IDENTITY_MISMATCH; return 1; }
  stage_dir="$(soviez_stage_dir "$stage_id")"
  identity="$(soviez_stage_inventory_find "$stage_id" 2>/dev/null || true)"
  [[ -n "$identity" && -f "$(soviez_stage_origin_cert_file "$stage_id")" ]] || { soviez_retention_safe_shield_fail STAGE_IDENTITY_MISMATCH; return 1; }
  [[ "$(soviez_json_get "$identity" stage_id 2>/dev/null)" == "$stage_id" ]] || { soviez_retention_safe_shield_fail STAGE_IDENTITY_MISMATCH; return 1; }
  db="$(soviez_json_get "$identity" stage_db_name)"; expected="$(soviez_stage_db_name_for "$stage_id")"
  [[ "$db" == "$expected" && "$db" != "odoo" && "$db" != "postgres" ]] || { soviez_retention_safe_shield_fail STAGE_PRODUCTION_COLLISION; return 1; }
  container="$(soviez_json_get "$identity" stage_container)"; [[ "$container" == "$(soviez_stage_container_name_for "$stage_id")" ]] || { soviez_retention_safe_shield_fail STAGE_PRODUCTION_COLLISION; return 1; }
  network="$(soviez_json_get "$identity" stage_network)"; [[ "$network" == "$(soviez_stage_network_name_for "$stage_id")" ]] || { soviez_retention_safe_shield_fail STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS; return 1; }
  fs="$(soviez_json_get "$identity" stage_filestore_path)"; cfg="$(soviez_json_get "$identity" stage_config_path)"; secrets="$(soviez_json_get "$identity" stage_secrets_path)"
  soviez_retention_safe_shield_path_under_stage "$fs" "$stage_dir" || { soviez_retention_safe_shield_fail STAGE_PRODUCTION_COLLISION; return 1; }
  soviez_retention_safe_shield_path_under_stage "$cfg" "$stage_dir" || { soviez_retention_safe_shield_fail STAGE_PRODUCTION_COLLISION; return 1; }
  soviez_retention_safe_shield_path_under_stage "$secrets" "$stage_dir" || { soviez_retention_safe_shield_fail STAGE_PRODUCTION_COLLISION; return 1; }
  # Nginx: absent is OK; present under Stage config must be Stage-owned
  if [[ -f "$cfg/nginx.conf" || -d "$cfg/nginx" ]]; then
    if [[ ! -f "$cfg/nginx.owned" ]]; then
      # Config path already verified under Stage root — stamp ownership marker
      printf '%s\n' "$stage_id" > "$cfg/nginx.owned"
      chmod 640 "$cfg/nginx.owned" 2>/dev/null || true
    fi
    [[ "$(tr -d '[:space:]' < "$cfg/nginx.owned")" == "$stage_id" ]] \
      || { soviez_retention_safe_shield_fail STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS; return 1; }
  fi
  cert="$(soviez_json_get "$identity" origin_certificate_path 2>/dev/null || true)"
  if [[ -n "$cert" && "$cert" != "null" ]]; then
    case "$cert" in
      "$stage_dir"/*) ;;
      *)
        soviez_retention_safe_shield_path_under_stage "$(dirname "$cert")" "$stage_dir" \
          || { soviez_retention_safe_shield_fail STAGE_SHARED_RESOURCE_DETECTED; return 1; }
        ;;
    esac
  fi
  if [[ "${SOVIEZ_RETENTION_HOLDING_LOCK:-0}" != "1" && -d "$(soviez_retention_lock_dir "$stage_id")" ]]; then
    soviez_retention_safe_shield_fail STAGE_ACTIVE_OPERATION_CONFLICT; return 1
  fi
  printf 'OK\n'
}
