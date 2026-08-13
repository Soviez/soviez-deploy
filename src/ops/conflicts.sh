# shellcheck shell=bash

soviez_ops_conflict_decide() {
  local a="$1" b="$2" env_a="$3" env_b="$4" overlap="$5"
  [[ "$a" == "ssl_renewal" && "$b" == "ssl_renewal" ]] && { [[ "$overlap" == "1" ]] && printf 'attach_existing\n' || printf 'allow\n'; return; }
  # Duplicate production_update on same env → attach_existing
  [[ "$a" == "production_update" && "$b" == "production_update" && "$overlap" == "1" ]] && { printf 'attach_existing\n'; return; }
  [[ "$env_a" != "$env_b" && "$overlap" != "1" ]] && { printf 'allow\n'; return; }
  case "$a:$b" in
    retention_delete:stage_backup|retention_delete:stage_drop|retention_delete:stage_restore|stage_backup:retention_delete|stage_drop:retention_delete|stage_restore:retention_delete|update:migrate|update:restore|migrate:update|restore:update) printf 'deny\n' ;;
    production_update:production_update|production_update:migrate|production_update:restore|production_update:stage_create|production_update:retention_delete|production_update:new|migrate:production_update|restore:production_update|stage_create:production_update|retention_delete:production_update|new:production_update)
      printf 'deny\n'
      ;;
    # New production_update supersedes scheduled/waiting image cleanup on same env.
    # Active deleting cleanup blocks update; cleanup vs active update is denied (cleanup aborts).
    production_update:update_image_cleanup)
      [[ "$overlap" == "1" ]] && printf 'supersede_cleanup\n' || printf 'allow\n'
      ;;
    update_image_cleanup:production_update)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    update_image_cleanup:update_image_cleanup)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    update_image_cleanup:stage_create|stage_create:update_image_cleanup)
      [[ "$overlap" == "1" ]] && printf 'wait\n' || printf 'allow\n'
      ;;
    production_update:ssl_renewal|production_update:ssl_repair|ssl_renewal:production_update|ssl_repair:production_update)
      # Nginx/cert promotion must not overlap final switch — wait when same env
      [[ "$overlap" == "1" ]] && printf 'wait\n' || printf 'allow\n'
      ;;
    production_update:stage_backup|stage_backup:production_update)
      # Unrelated manual backup only safe before protected work; treat as wait on overlap
      [[ "$overlap" == "1" ]] && printf 'wait\n' || printf 'allow\n'
      ;;
    # Phase 16 — one data-heavy backup/restore per host when scopes overlap
    production_backup:production_backup|production_backup:production_restore|production_restore:production_backup|production_restore:production_restore|production_backup:production_update|production_update:production_backup|production_restore:production_update|production_update:production_restore|production_backup:migrate|migrate:production_backup|production_restore:migrate|migrate:production_restore|backup_restore_test:production_restore|production_restore:backup_restore_test|backup_restore_test:production_backup|production_backup:backup_restore_test)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    production_backup:backup_retention_cleanup|backup_retention_cleanup:production_backup|production_restore:backup_retention_cleanup|backup_retention_cleanup:production_restore|backup_verification:backup_retention_cleanup|backup_retention_cleanup:backup_verification)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    production_backup:ssl_renewal|ssl_renewal:production_backup)
      [[ "$overlap" == "1" ]] && printf 'wait\n' || printf 'allow\n'
      ;;
    # Phase 17 — migration preparation ops
    migration_source_discovery:migration_source_discovery|migration_destination_bootstrap:migration_destination_bootstrap|migration_trust_pairing:migration_trust_pairing|migration_domain_plan:migration_domain_plan|migration_dns_challenge:migration_dns_challenge|migration_landing_prepare:migration_landing_prepare|migration_tls_prepare:migration_tls_prepare|migration_routing_readiness:migration_routing_readiness)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_domain_plan:migrate|migrate:migration_domain_plan|migration_dns_challenge:migrate|migrate:migration_dns_challenge|migration_landing_prepare:migrate|migrate:migration_landing_prepare|migration_tls_prepare:migrate|migrate:migration_tls_prepare|migration_routing_readiness:migrate|migrate:migration_routing_readiness|migration_domain_abort:migrate|migrate:migration_domain_abort)
      printf 'deny\n'
      ;;
    migration_domain_abort:*)
      printf 'allow\n'
      ;;
    migration_tls_prepare:ssl_renewal|ssl_renewal:migration_tls_prepare)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_source_discovery:production_update|production_update:migration_source_discovery|migration_source_discovery:production_restore|production_restore:migration_source_discovery|migration_trust_pairing:production_update|production_update:migration_trust_pairing|migration_trust_pairing:production_restore|production_restore:migration_trust_pairing|migration_source_discovery:migrate|migrate:migration_source_discovery|migration_destination_bootstrap:migrate|migrate:migration_destination_bootstrap|migration_trust_pairing:migrate|migrate:migration_trust_pairing|migration_readiness_assessment:migrate|migrate:migration_readiness_assessment)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_pair_abort:*)
      printf 'allow\n'
      ;;
    # Phase 19 — deny overlapping transfer ops on same host; abort always allowed
    migration_transfer_plan:migration_transfer_plan|migration_payload_presync:migration_payload_presync|migration_database_transfer:migration_database_transfer|migration_filestore_transfer:migration_filestore_transfer|migration_addon_transfer:migration_addon_transfer|migration_config_transfer:migration_config_transfer|migration_stage_transfer:migration_stage_transfer|migration_final_sync:migration_final_sync|migration_destination_verify:migration_destination_verify)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_transfer_plan:migration_final_sync|migration_final_sync:migration_transfer_plan|migration_payload_presync:migration_final_sync|migration_final_sync:migration_payload_presync|migration_database_transfer:migration_final_sync|migration_final_sync:migration_database_transfer|migration_filestore_transfer:migration_final_sync|migration_final_sync:migration_filestore_transfer)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_final_sync:production_update|production_update:migration_final_sync|migration_final_sync:production_restore|production_restore:migration_final_sync|migration_final_sync:production_backup|production_backup:migration_final_sync|migration_final_sync:migrate|migrate:migration_final_sync|migration_payload_presync:production_update|production_update:migration_payload_presync|migration_payload_presync:production_backup|production_backup:migration_payload_presync)
      [[ "$overlap" == "1" ]] && printf 'deny\n' || printf 'allow\n'
      ;;
    migration_transfer_abort:*|*:migration_transfer_abort)
      printf 'allow\n'
      ;;
    *) [[ "$overlap" == "1" ]] && printf 'wait\n' || printf 'allow\n' ;;
  esac
}

soviez_ops_conflict_check() {
  local op_type="$1" env_id="$2" resources="${3:-}" file rec existing_type existing_env existing_state decision sync_status op_id
  shopt -s nullglob
  for file in "$SOVIEZ_OPS_INDEX_DIR"/*.json; do
    [[ -f "$file" ]] || continue; rec="$(cat "$file")"
    existing_state="$(soviez_json_get "$rec" current_state 2>/dev/null || true)"
    case "$existing_state" in completed|canceled|failed_terminal) continue ;; esac
    existing_type="$(soviez_json_get "$rec" operation_type 2>/dev/null || true)"
    existing_env="$(soviez_json_get "$rec" environment_id 2>/dev/null || true)"
    op_id="$(soviez_json_get "$rec" operation_id 2>/dev/null || true)"
    [[ -n "$existing_type" ]] || continue
    # Stale/incomplete canonical sync on overlapping resource → fail closed
    if [[ -n "$op_id" ]] && [[ "$env_id" == "$existing_env" && -n "$env_id" ]]; then
      if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
        soviez_ops_die OPERATION_CANONICAL_SYNC_PENDING "Conflicting operation has unsynchronized canonical state: $op_id"
      fi
      if [[ -f "$(soviez_ops_canonical_state_path "$op_id")" ]]; then
        sync_status="$(soviez_json_get "$(cat "$(soviez_ops_canonical_state_path "$op_id")")" canonical_sync_status 2>/dev/null || true)"
        case "$sync_status" in
          pending|incomplete|failed|stale)
            soviez_ops_die OPERATION_CANONICAL_STATE_STALE "Stale canonical state blocks conflict decision: $op_id"
            ;;
        esac
      fi
    fi
    decision="$(soviez_ops_conflict_decide "$op_type" "$existing_type" "$env_id" "$existing_env" "$([[ "$env_id" == "$existing_env" && -n "$env_id" ]] && echo 1 || echo 0)")"
    case "$decision" in
      deny|requires_recovery)
        # If existing cleanup is actively deleting, keep deny; if only scheduled, treat as supersede for production_update
        if [[ "$decision" == "deny" && "$op_type" == "production_update" && "$existing_type" == "update_image_cleanup" ]]; then
          case "$existing_state" in
            deleting|running|executing)
              soviez_ops_die OPERATION_RESOURCE_CONFLICT "Conflicting operation: $existing_type ($existing_state)"
              ;;
            *)
              decision="supersede_cleanup"
              ;;
          esac
        else
          soviez_ops_die OPERATION_RESOURCE_CONFLICT "Conflicting operation: $existing_type ($existing_state)"
        fi
        ;;
    esac
    if [[ "$decision" == "supersede_cleanup" ]]; then
      case "$existing_state" in
        deleting|running|executing)
          soviez_ops_die OPERATION_RESOURCE_CONFLICT "Conflicting operation: $existing_type ($existing_state)"
          ;;
        *)
          # Abort scheduled/waiting cleanup so a new update can proceed; cleanup must revalidate later.
          SOVIEZ_REC="$rec" SOVIEZ_FILE="$file" python3 - <<'PY' 2>/dev/null || true
import json,os
path=os.environ["SOVIEZ_FILE"]
with open(path,encoding="utf-8") as f: d=json.load(f)
d["current_state"]="canceled"
d["checkpoint"]="superseded_by_production_update"
d["cancel_reason"]="new_production_update"
with open(path,"w",encoding="utf-8") as f:
  json.dump(d,f,separators=(",",":")); f.write("\n")
PY
          if [[ -n "$op_id" ]] && declare -F soviez_ops_sync_terminal >/dev/null 2>&1; then
            soviez_ops_sync_terminal "$op_id" update_image_cleanup "$existing_env" canceled "$file" 2>/dev/null || true
          fi
          # Also mark image-cleanup local state if present
          local ic_state="${SOVIEZ_IMAGE_CLEANUP_DIR:-${SOVIEZ_UPDATE_ROOT:-$SOVIEZ_ROOT/update}/image_cleanup}/operations/$op_id/state.json"
          if [[ -n "$op_id" && -f "$ic_state" ]]; then
            soviez_json_merge_file "$ic_state" \
              '{"current_state":"canceled","checkpoint":"superseded_by_production_update"}' 2>/dev/null || true
          fi
          continue
          ;;
      esac
    fi
  done
}
