# shellcheck shell=bash

soviez_main() {
  export SOVIEZ_SH_ROOT="${SOVIEZ_SH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || pwd)}"
  # When running from generated dist/soviez.sh, SOVIEZ_SH_ROOT should be repo root (parent of dist/).
  if [[ -f "${SOVIEZ_SH_ROOT}/dist/soviez.sh" && ! -d "${SOVIEZ_SH_ROOT}/services" ]]; then
    :
  elif [[ -f "${SOVIEZ_SH_ROOT}/soviez.sh" && -d "${SOVIEZ_SH_ROOT}/../services" ]]; then
    SOVIEZ_SH_ROOT="$(cd "${SOVIEZ_SH_ROOT}/.." && pwd)"
  fi
  # Prefer repo root detection from BASH_SOURCE of this assembled script location.
  local _here
  _here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [[ -n "$_here" && -d "$_here/../services/stage-operation-helper" ]]; then
    SOVIEZ_SH_ROOT="$(cd "$_here/.." && pwd)"
  elif [[ -n "$_here" && -d "$_here/services/stage-operation-helper" ]]; then
    SOVIEZ_SH_ROOT="$_here"
  fi
  export SOVIEZ_SH_ROOT
  soviez_paths_init
  soviez_stage_paths_init 2>/dev/null || true
  soviez_ssl_paths_init 2>/dev/null || true
  soviez_ops_paths_init 2>/dev/null || true
  soviez_cli_parse "$@"

  # Signed platform self-update preflight (mutating commands); read-only is best-effort.
  if declare -F soviez_platform_self_update_maybe >/dev/null 2>&1; then
    soviez_platform_self_update_maybe "$@" || {
      echo "[error] platform self-update preflight failed" >&2
      exit 1
    }
  fi

  case "$SOVIEZ_CLI_COMMAND" in
    version) soviez_cmd_version_run ;;
    list) soviez_cmd_list_run ;;
    tune) soviez_cmd_tune_run ;;
    platform-install) soviez_cmd_platform_install_run ;;
    new) soviez_cmd_new_run ;;
    reattach) soviez_cmd_reattach_run ;;
    stage|stage-reattach)
      if [[ "${SOVIEZ_CLI_OFFLINE_MODE:-}" == "request" ]]; then
        soviez_cmd_stage_offline_request
      elif [[ "${SOVIEZ_CLI_OFFLINE_MODE:-}" == "import" ]]; then
        soviez_cmd_stage_offline_import
      else
        soviez_cmd_stage_create_run
      fi
      ;;
    stage-list) soviez_stage_cmd_list ;;
    stage-status) soviez_stage_cmd_status "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-start) soviez_stage_cmd_start "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-stop) soviez_stage_cmd_stop "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-backup) soviez_stage_cmd_backup "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-drop) soviez_stage_cmd_drop "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-retention-status) soviez_cmd_stage_retention_status "${SOVIEZ_CLI_STAGE_TARGET:-}" ;;
    stage-retention-extend) soviez_cmd_stage_retention_extend "$SOVIEZ_CLI_STAGE_TARGET" "$SOVIEZ_CLI_RETENTION_DAYS" "${SOVIEZ_CLI_RETENTION_YES:-}" ;;
    stage-retention-run) soviez_cmd_stage_retention_run "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-retention-retry) soviez_cmd_stage_retention_retry "$SOVIEZ_CLI_STAGE_TARGET" ;;
    stage-retention-reattach) soviez_cmd_stage_retention_reattach "$SOVIEZ_CLI_OP_ID" ;;
    ssl-status) soviez_cmd_ssl_status "${SOVIEZ_CLI_SSL_TARGET:-}" ;;
    ssl-renew) soviez_cmd_ssl_renew "$SOVIEZ_CLI_SSL_TARGET" ;;
    ssl-repair) soviez_cmd_ssl_repair "$SOVIEZ_CLI_SSL_TARGET" ;;
    ssl-reattach) soviez_cmd_ssl_reattach "$SOVIEZ_CLI_OP_ID" ;;
    ssl-policy) soviez_cmd_ssl_policy "$SOVIEZ_CLI_SSL_TARGET" "${SOVIEZ_CLI_SSL_POLICY_MODE:-}" ;;
    ssl-try-again) soviez_cmd_ssl_try_again "$SOVIEZ_CLI_SSL_TARGET" ;;
    ssl-abort) soviez_cmd_ssl_abort "$SOVIEZ_CLI_SSL_TARGET" ;;
    operations-list) soviez_cmd_operations_list "${SOVIEZ_CLI_OPS_FILTER:-}" "${SOVIEZ_CLI_OPS_FILTER_VALUE:-}" ;;
    operation-status) soviez_cmd_operation_status "$SOVIEZ_CLI_OP_ID" ;;
    operation-reattach) soviez_cmd_operation_reattach "$SOVIEZ_CLI_OP_ID" ;;
    operation-cancel) soviez_cmd_operation_cancel "$SOVIEZ_CLI_OP_ID" "${SOVIEZ_CLI_RETENTION_YES:-}" ;;
    operation-retry) soviez_cmd_operation_retry "$SOVIEZ_CLI_OP_ID" "${SOVIEZ_CLI_RETENTION_YES:-}" ;;
    operation-recover) soviez_cmd_operation_recover "$SOVIEZ_CLI_OP_ID" "${SOVIEZ_CLI_RETENTION_YES:-}" ;;
    operation-logs) soviez_cmd_operation_logs "$SOVIEZ_CLI_OP_ID" ;;
    operation-reconcile) soviez_cmd_operation_reconcile "${SOVIEZ_CLI_OP_ID:-}" ;;
    update)
      soviez_update_paths_init 2>/dev/null || true
      soviez_cmd_update_run
      ;;
    update-status) soviez_cmd_update_status "$SOVIEZ_CLI_OP_ID" ;;
    update-reattach) soviez_cmd_update_reattach "$SOVIEZ_CLI_OP_ID" ;;
    update-cancel) soviez_cmd_update_cancel "$SOVIEZ_CLI_OP_ID" ;;
    update-retry) soviez_cmd_update_retry "$SOVIEZ_CLI_OP_ID" ;;
    update-recover) soviez_cmd_update_recover "$SOVIEZ_CLI_OP_ID" ;;
    update-rollback) soviez_cmd_update_rollback "$SOVIEZ_CLI_OP_ID" ;;
    update-cleanup) soviez_cmd_update_cleanup "$SOVIEZ_CLI_OP_ID" ;;
    update-image-status) soviez_cmd_update_image_status ;;
    update-image-cleanup|update-image-cleanup-retry) soviez_cmd_update_image_cleanup ;;
    offline-bundle-inspect) soviez_cmd_offline_bundle_inspect ;;
    offline-bundle-import) soviez_cmd_offline_bundle_import ;;
    offline-bundle-plan) soviez_cmd_offline_bundle_plan ;;
    offline-update-apply) soviez_cmd_offline_update_apply ;;
    offline-update-status) soviez_cmd_offline_update_status ;;
    offline-update-result-export) soviez_cmd_offline_update_result_export ;;
    offline-update-result-show) soviez_cmd_offline_update_result_show ;;
    offline-trust-inspect) soviez_cmd_offline_trust_inspect ;;
    offline-trust-import) soviez_cmd_offline_trust_import ;;
    offline-phase24-readiness) soviez_cmd_offline_phase24_readiness ;;
    security-status) soviez_cmd_security_status ;;
    security-check) soviez_cmd_security_check ;;
    security-harden) soviez_cmd_security_harden ;;
    security-report) soviez_cmd_security_report ;;
    security-scan) soviez_cmd_security_scan ;;
    security-scan-db) soviez_cmd_security_scan_db ;;
    security-quarantine-create) soviez_cmd_security_quarantine_create ;;
    security-quarantine-status) soviez_cmd_security_quarantine_status ;;
    security-quarantine-scan) soviez_cmd_security_quarantine_scan ;;
    security-quarantine-promote) soviez_cmd_security_quarantine_promote ;;
    security-quarantine-reject) soviez_cmd_security_quarantine_reject ;;
    security-quarantine-accept-review) soviez_cmd_security_quarantine_accept_review ;;
    security-update-check) soviez_cmd_security_update_check ;;
    security-backup-check) soviez_cmd_security_backup_check ;;
    security-backup-retention) soviez_cmd_security_backup_retention ;;
    security-phase25-readiness) soviez_cmd_security_phase25_readiness ;;
    backup) soviez_cmd_backup_run ;;
    backup-status) soviez_cmd_backup_status "$SOVIEZ_CLI_OP_ID" ;;
    backup-list) soviez_cmd_backup_list ;;
    backup-show) soviez_cmd_backup_show "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-verify) soviez_cmd_backup_verify "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-restore-test) soviez_cmd_backup_restore_test "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-export) soviez_cmd_backup_export "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-import) soviez_cmd_backup_import "$SOVIEZ_CLI_BACKUP_IMPORT_PATH" ;;
    backup-delete) soviez_cmd_backup_delete "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-pin) soviez_cmd_backup_pin "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-unpin) soviez_cmd_backup_unpin "$SOVIEZ_CLI_BACKUP_ID" ;;
    backup-retention-status) soviez_cmd_backup_retention_status ;;
    backup-retention-cleanup) soviez_cmd_backup_retention_cleanup ;;
    backup-destination-list) soviez_cmd_backup_destination_list ;;
    backup-destination-show) soviez_cmd_backup_destination_show "$SOVIEZ_CLI_BACKUP_DESTINATION" ;;
    backup-destination-test) soviez_cmd_backup_destination_test "$SOVIEZ_CLI_BACKUP_DESTINATION" ;;
    backup-schedule-list) soviez_cmd_backup_schedule_list ;;
    backup-schedule-add) soviez_cmd_backup_schedule_add ;;
    restore) soviez_cmd_restore_run ;;
    restore-status) soviez_cmd_restore_status "$SOVIEZ_CLI_OP_ID" ;;
    restore-cancel) soviez_cmd_restore_cancel "$SOVIEZ_CLI_OP_ID" ;;
    restore-retry) soviez_cmd_restore_retry "$SOVIEZ_CLI_OP_ID" ;;
    restore-recover) soviez_cmd_restore_recover "$SOVIEZ_CLI_OP_ID" ;;
    restore-rollback) soviez_cmd_restore_rollback "$SOVIEZ_CLI_OP_ID" ;;
    restore-cleanup) soviez_cmd_restore_cleanup "$SOVIEZ_CLI_OP_ID" ;;
    restore-test) soviez_cmd_restore_test "$SOVIEZ_CLI_BACKUP_ID" ;;
    restore-as-stage) soviez_cmd_restore_as_stage ;;
    migration-discover) soviez_cmd_migration_discover ;;
    migration-discovery-show) soviez_cmd_migration_discovery_show ;;
    migration-bootstrap-destination) soviez_cmd_migration_bootstrap_destination ;;
    migration-bootstrap-status) soviez_cmd_migration_bootstrap_status ;;
    migration-bootstrap-export) soviez_cmd_migration_bootstrap_export ;;
    migration-bootstrap-import) soviez_cmd_migration_bootstrap_import ;;
    migration-pair) soviez_cmd_migration_pair ;;
    migration-pair-status) soviez_cmd_migration_pair_status ;;
    migration-pair-export) soviez_cmd_migration_pair_export ;;
    migration-pair-import) soviez_cmd_migration_pair_import ;;
    migration-readiness) soviez_cmd_migration_readiness ;;
    migration-readiness-show) soviez_cmd_migration_readiness_show ;;
    migration-readiness-export) soviez_cmd_migration_readiness_export ;;
    migration-readiness-import) soviez_cmd_migration_readiness_import ;;
    migration-stage-select) soviez_cmd_migration_stage_select ;;
    migration-stage-unselect) soviez_cmd_migration_stage_unselect ;;
    migration-abort) soviez_cmd_migration_abort ;;
    migration-domain-plan) soviez_cmd_migration_domain_plan ;;
    migration-domain-plan-show) soviez_cmd_migration_domain_plan_show ;;
    migration-dns-challenge-create|migration-dns-challenge) soviez_cmd_migration_dns_challenge_create ;;
    migration-dns-challenge-verify) soviez_cmd_migration_dns_challenge_verify ;;
    migration-dns-show) soviez_cmd_migration_dns_show ;;
    migration-dns-challenge-abort|migration-dns-abort) soviez_cmd_migration_dns_challenge_abort ;;
    migration-dns-challenge-retry) soviez_cmd_migration_dns_challenge_retry ;;
    migration-dns-try-again) soviez_cmd_migration_dns_try_again ;;
    migration-dns-instructions) soviez_cmd_migration_dns_instructions ;;
    migration-landing-prepare) soviez_cmd_migration_landing_prepare ;;
    migration-landing-status) soviez_cmd_migration_landing_status ;;
    migration-landing-cleanup) soviez_cmd_migration_landing_cleanup ;;
    migration-tls-prepare) soviez_cmd_migration_tls_prepare ;;
    migration-tls-status) soviez_cmd_migration_tls_status ;;
    migration-tls-revoke) soviez_cmd_migration_tls_revoke ;;
    migration-routing-readiness) soviez_cmd_migration_routing_readiness ;;
    migration-routing-show) soviez_cmd_migration_routing_show ;;
    migration-domain-abort) soviez_cmd_migration_domain_abort ;;
    migration-transfer-plan) soviez_cmd_migration_transfer_plan ;;
    migration-transfer-plan-show) soviez_cmd_migration_transfer_plan_show ;;
    migration-presync) soviez_cmd_migration_presync ;;
    migration-presync-status) soviez_cmd_migration_presync_status ;;
    migration-transfer-start) soviez_cmd_migration_transfer_start ;;
    migration-transfer-status) soviez_cmd_migration_transfer_status ;;
    migration-transfer-pause) soviez_cmd_migration_transfer_pause ;;
    migration-transfer-resume) soviez_cmd_migration_transfer_resume ;;
    migration-transfer-cancel) soviez_cmd_migration_transfer_cancel ;;
    migration-transfer-retry) soviez_cmd_migration_transfer_retry ;;
    migration-transfer-recover) soviez_cmd_migration_transfer_recover ;;
    migration-destination-verify) soviez_cmd_migration_destination_verify ;;
    migration-transfer-abort) soviez_cmd_migration_transfer_abort ;;
    migration-transfer-cleanup) soviez_cmd_migration_transfer_cleanup ;;
    migration-stage-mark-mandatory) soviez_cmd_migration_stage_mark_mandatory ;;
    migration-stage-mark-optional) soviez_cmd_migration_stage_mark_optional ;;
    migration-authorization-plan) soviez_cmd_migration_authorization_plan ;;
    migration-authorization-show) soviez_cmd_migration_authorization_show ;;
    migration-activate-destination) soviez_cmd_migration_activate_destination ;;
    migration-activation-status) soviez_cmd_migration_activation_status ;;
    migration-activation-retry) soviez_cmd_migration_activation_retry ;;
    migration-activation-recover) soviez_cmd_migration_activation_recover ;;
    migration-source-grace-status) soviez_cmd_migration_source_grace_status ;;
    migration-stage-rebind-status) soviez_cmd_migration_stage_rebind_status ;;
    migration-phase21-readiness) soviez_cmd_migration_phase21_readiness ;;
    migration-phase21-readiness-show) soviez_cmd_migration_phase21_readiness_show ;;
    migration-authorization-export) soviez_cmd_migration_authorization_export ;;
    migration-authorization-import) soviez_cmd_migration_authorization_import ;;
    migration-cutover-plan) soviez_cmd_migration_cutover_plan ;;
    migration-cutover-plan-show) soviez_cmd_migration_cutover_plan_show ;;
    migration-cutover-start) soviez_cmd_migration_cutover_start ;;
    migration-cutover-status) soviez_cmd_migration_cutover_status ;;
    migration-cutover-retry) soviez_cmd_migration_cutover_retry ;;
    migration-cutover-recover) soviez_cmd_migration_cutover_recover ;;
    migration-cutover-dns-show) soviez_cmd_migration_cutover_dns_show ;;
    migration-cutover-dns-try-again) soviez_cmd_migration_cutover_dns_try_again ;;
    migration-cutover-rollback) soviez_cmd_migration_cutover_rollback ;;
    migration-traffic-owner-show) soviez_cmd_migration_traffic_owner_show ;;
    migration-phase22-readiness) soviez_cmd_migration_phase22_readiness ;;
    migration-phase22-readiness-show) soviez_cmd_migration_phase22_readiness_show ;;
    migration-stabilization-status) soviez_cmd_migration_stabilization_status ;;
    migration-rollback-window-close-plan) soviez_cmd_migration_rollback_window_close_plan ;;
    migration-rollback-window-close) soviez_cmd_migration_rollback_window_close ;;
    migration-rollback-window-close-status) soviez_cmd_migration_rollback_window_close_status ;;
    migration-source-archive-plan) soviez_cmd_migration_source_archive_plan ;;
    migration-source-archive-start) soviez_cmd_migration_source_archive_start ;;
    migration-source-archive-status) soviez_cmd_migration_source_archive_status ;;
    migration-source-archive-retry) soviez_cmd_migration_source_archive_retry ;;
    migration-source-archive-recover) soviez_cmd_migration_source_archive_recover ;;
    migration-source-license-finalize) soviez_cmd_migration_source_license_finalize ;;
    migration-source-credentials-status) soviez_cmd_migration_source_credentials_status ;;
    migration-source-runtime-suspend) soviez_cmd_migration_source_runtime_suspend ;;
    migration-source-retirement-status) soviez_cmd_migration_source_retirement_status ;;
    migration-phase23-readiness) soviez_cmd_migration_phase23_readiness ;;
    migration-phase23-readiness-show) soviez_cmd_migration_phase23_readiness_show ;;
    migration-status) soviez_cmd_migration_status ;;
    migration-reattach) soviez_cmd_migration_reattach ;;
    migration-cancel) soviez_cmd_migration_cancel ;;
    migration-retry) soviez_cmd_migration_retry ;;
    migration-recover) soviez_cmd_migration_recover ;;
    *) soviez_die "$SOVIEZ_ERR_USAGE" "Unknown command" ;;
  esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
  soviez_main "$@"
fi
