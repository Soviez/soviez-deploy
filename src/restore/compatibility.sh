# shellcheck shell=bash

soviez_restore_compatibility_check() {
  # Args: production_json backup_object_json
  local prod="$1" backup="$2"
  local prod_id bk_prod license_id bk_license db_uuid bk_uuid host_now bk_host
  local btype vstatus

  prod_id="$(soviez_json_get "$prod" tenant_id)"
  bk_prod="$(soviez_json_get "$backup" production_id)"
  [[ "$prod_id" == "$bk_prod" ]] || soviez_restore_die RESTORE_WRONG_PRODUCTION "Backup belongs to $bk_prod not $prod_id"

  license_id="$(soviez_json_get "$prod" license_id)"
  bk_license="$(soviez_json_get "$backup" license_id)"
  [[ "$license_id" == "$bk_license" ]] || soviez_restore_die RESTORE_LICENSE_BINDING_MISMATCH "License mismatch"

  db_uuid="$(soviez_json_get "$prod" database_uuid)"
  bk_uuid="$(soviez_json_get "$backup" database_uuid)"
  [[ "$db_uuid" == "$bk_uuid" ]] || soviez_restore_die RESTORE_BACKUP_OWNERSHIP_MISMATCH "database_uuid mismatch"

  # Same-host only (Phase 16)
  host_now="$(hostname -f 2>/dev/null || hostname || echo unknown)"
  bk_host="$(soviez_json_get "$backup" host_identity 2>/dev/null || true)"
  local prod_host
  prod_host="$(soviez_json_get "$prod" host_identity 2>/dev/null || true)"
  if [[ -n "$bk_host" && "$bk_host" != "null" && "$bk_host" != "unknown" ]]; then
    [[ "$bk_host" == "$host_now" || "$bk_host" == "$(hostname 2>/dev/null || true)" ]] \
      || soviez_restore_die RESTORE_HOST_IDENTITY_MISMATCH "Cross-host restore denied"
  fi
  if [[ -n "$prod_host" && "$prod_host" != "null" && "$prod_host" != "unknown" ]]; then
    [[ "$prod_host" == "$host_now" || "$prod_host" == "$(hostname 2>/dev/null || true)" ]] \
      || soviez_restore_die RESTORE_HOST_IDENTITY_MISMATCH "Production host identity mismatch"
  fi

  btype="$(soviez_json_get "$backup" backup_type)"
  if [[ "$btype" == "database_only" || "$btype" == "database-only" ]]; then
    soviez_restore_die RESTORE_DATABASE_ONLY_BACKUP_DENIED "database-only is not a full restore source"
  fi

  vstatus="$(soviez_json_get "$backup" verification_status 2>/dev/null || echo none)"
  if [[ "$vstatus" != "VERIFIED" && "${SOVIEZ_RESTORE_ALLOW_UNVERIFIED:-0}" != "1" ]]; then
    soviez_restore_die RESTORE_BACKUP_NOT_VERIFIED "Backup not verified"
  fi

  # ERP major soft check
  local prod_major bk_major
  prod_major="$(soviez_json_get "$prod" erp_major 2>/dev/null || true)"
  bk_major="$(soviez_json_get "$backup" erp_major 2>/dev/null || true)"
  if [[ -n "$prod_major" && -n "$bk_major" && "$prod_major" != "$bk_major" && "$prod_major" != "null" && "$bk_major" != "null" ]]; then
    soviez_restore_die RESTORE_ERP_VERSION_INCOMPATIBLE "ERP major $bk_major incompatible with $prod_major"
  fi

  printf '%s' '{"ok":true,"compatible":true}'
}
