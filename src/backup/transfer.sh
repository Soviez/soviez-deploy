# shellcheck shell=bash

soviez_backup_transfer() {
  # Args: destination_profile_json staging_dir backup_id production_id
  local profile="$1" src="$2" backup_id="$3" prod_id="$4"
  local kind location
  kind="$(soviez_json_get "$profile" kind)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "$kind" != "local" ]]; then
    # Fixture: still exercise kind helpers when present; else cp to fixture root
    case "$kind" in
      s3)
        location="$(soviez_backup_s3_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
        ;;
      sftp)
        location="$(soviez_backup_sftp_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
        ;;
      *)
        location="$(soviez_backup_local_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
        ;;
    esac
    printf '%s' "$location"
    return 0
  fi

  case "$kind" in
    local)
      location="$(soviez_backup_local_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
      ;;
    s3)
      location="$(soviez_backup_s3_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
      ;;
    sftp)
      location="$(soviez_backup_sftp_dest_put "$profile" "$src" "$backup_id" "$prod_id")"
      ;;
    *)
      soviez_backup_die BACKUP_DESTINATION_INVALID "Unsupported transfer kind: $kind"
      ;;
  esac
  printf '%s' "$location"
}
