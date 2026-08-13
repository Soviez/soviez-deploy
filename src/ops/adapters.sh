# shellcheck shell=bash

# Adapter metadata deliberately delegates execution to existing Phase 8/11/12/13 engines.
soviez_ops_adapter_types() { printf '%s\n' new stage_create ssl_renewal ssl_repair retention_delete production_update update_image_cleanup production_backup backup_verification backup_restore_test production_restore backup_retention_cleanup backup_export backup_import; }
soviez_ops_adapter_resource_scopes() {
  local type="$1" env="$2"
  case "$type" in
    ssl_renewal|ssl_repair) printf 'nginx:%s\n' "$env" ;;
    retention_delete) printf 'env:%s\ndb:stage_%s\n' "$env" "${env//-/_}" ;;
    production_update) printf 'env:%s\ndb:prod_%s\nfilestore:prod_%s\nruntime:prod_%s\n' "$env" "$env" "$env" "$env" ;;
    update_image_cleanup) printf 'image:soviez_erp\nenv:%s\n' "$env" ;;
    production_backup|backup_verification|backup_restore_test|production_restore|backup_export|backup_import)
      printf 'env:%s\ndb:prod_%s\nfilestore:prod_%s\nbackup:prod_%s\n' "$env" "$env" "$env" "$env" ;;
    backup_retention_cleanup) printf 'backup:host\nenv:%s\n' "$env" ;;
    *) printf 'env:%s\n' "$env" ;;
  esac
}
soviez_ops_adapter_cancel_boundary() {
  local type="$1" checkpoint="$2"
  case "$type:$checkpoint" in
    retention_delete:delete_*|stage_create:database_restore|new:tenant_identity_created|production_update:switching|production_update:validating_production|update_image_cleanup:deleting|production_restore:switching|production_restore:validating_production)
      printf 'irreversible\n'
      ;;
    ssl_renewal:promote_*|ssl_repair:promote_*|retention_delete:nginx_*|stage_create:nginx_*|production_update:upgrading_candidate|production_update:creating_backup|production_update:preparing_candidate|production_restore:restoring_*|production_backup:backing_up_*|production_backup:quiescing_application)
      printf 'rollback\n'
      ;;
    update_image_cleanup:*|backup_retention_cleanup:*)
      printf 'cancelable\n'
      ;;
    *)
      printf 'cancelable\n'
      ;;
  esac
}

soviez_ops_adapter_reattach() {
  local op_id="$1" type="$2"
  case "$type" in
    new) SOVIEZ_CLI_OP_ID="$op_id" soviez_cmd_reattach_run ;;
    stage_create|stage_lifecycle) SOVIEZ_CLI_OP_ID="$op_id" soviez_cmd_stage_create_run ;;
    ssl_renewal|ssl_repair) soviez_cmd_ssl_reattach "$op_id" ;;
    production_update) SOVIEZ_CLI_OP_ID="$op_id" soviez_cmd_update_reattach "$op_id" ;;
    update_image_cleanup) soviez_image_cleanup_scheduler_tick ;;
    production_backup|backup_verification|backup_restore_test|backup_export|backup_import)
      SOVIEZ_CLI_OP_ID="$op_id" soviez_cmd_backup_status "$op_id" ;;
    production_restore)
      SOVIEZ_CLI_OP_ID="$op_id" soviez_cmd_restore_status "$op_id" ;;
    backup_retention_cleanup)
      if declare -F soviez_backup_retention_cleanup >/dev/null 2>&1; then
        soviez_backup_retention_cleanup 1 "" 0
      fi
      ;;
    retention_delete)
      if declare -F soviez_cmd_stage_retention_reattach >/dev/null 2>&1; then
        soviez_cmd_stage_retention_reattach "$op_id"
      else
        local env_id
        env_id="$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op_id")")" environment_id)"
        soviez_retention_retry "$env_id"
      fi
      ;;
    *) soviez_ops_worker_reattach "$op_id" || true ;;
  esac
}
