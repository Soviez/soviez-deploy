# shellcheck shell=bash

SOVIEZ_CLI_COMMAND=""
SOVIEZ_CLI_OP_ID=""
SOVIEZ_CLI_DOMAIN=""
SOVIEZ_CLI_ACTIVATION_METHOD="automatic"
SOVIEZ_CLI_CHANNEL="stable"
SOVIEZ_CLI_STAGE_ID=""
SOVIEZ_CLI_STAGE_DOMAIN=""
SOVIEZ_CLI_PRODUCTION_TENANT=""
SOVIEZ_CLI_STAGE_TARGET=""
SOVIEZ_CLI_OFFLINE_MODE=""
SOVIEZ_CLI_OFFLINE_PACKAGE=""
SOVIEZ_CLI_OFFLINE_OUT=""
SOVIEZ_CLI_SSL_TARGET=""
SOVIEZ_CLI_SSL_POLICY_MODE=""
SOVIEZ_CLI_RETENTION_DAYS=""
SOVIEZ_CLI_RETENTION_YES=""
SOVIEZ_CLI_UPDATE_TARGET=""
SOVIEZ_CLI_UPDATE_RELEASE=""
SOVIEZ_CLI_UPDATE_OFFLINE_PACKAGE=""
SOVIEZ_CLI_CONFIRM="0"
SOVIEZ_CLI_YES="0"
SOVIEZ_CLI_DRY_RUN="0"
SOVIEZ_CLI_ADVANCED="0"
SOVIEZ_CLI_BACKUP_TARGET=""
SOVIEZ_CLI_BACKUP_DESTINATION=""
SOVIEZ_CLI_BACKUP_TYPE="full"
SOVIEZ_CLI_BACKUP_ID=""
SOVIEZ_CLI_BACKUP_PRODUCTION=""
SOVIEZ_CLI_BACKUP_OUTPUT=""
SOVIEZ_CLI_BACKUP_IMPORT_PATH=""
SOVIEZ_CLI_BACKUP_RETENTION_EXECUTE="0"
SOVIEZ_CLI_RESTORE_TARGET=""
SOVIEZ_CLI_RESTORE_BACKUP=""
SOVIEZ_CLI_TARGET=""

soviez_cli_usage() {
  cat <<EOF
Usage: soviez.sh --new [options]
       soviez.sh --reattach <operation-id>
       soviez.sh --update <production-environment-id> [--release ID] [--offline-package PATH] [--confirm]
       soviez.sh --update-status <operation-id>
       soviez.sh --update-reattach <operation-id>
       soviez.sh --update-cancel <operation-id>
       soviez.sh --update-retry <operation-id>
       soviez.sh --update-recover <operation-id>
       soviez.sh --update-rollback <operation-id>
       soviez.sh --update-cleanup <operation-id> --confirm
       soviez.sh --update-image-status [--production ID]
       soviez.sh --update-image-cleanup [--dry-run] [--production ID] [--confirm]
       soviez.sh --update-image-cleanup --retry <operation-id>
       soviez.sh --stage [options]
       soviez.sh --stage-list
       soviez.sh --stage-status <stage-id>
       soviez.sh --stage-start <stage-id>
       soviez.sh --stage-stop <stage-id>
       soviez.sh --stage-backup <stage-id>
       soviez.sh --stage-drop <stage-id>
       soviez.sh --stage-reattach <operation-id>
       soviez.sh --stage-retention-status [stage-id]
       soviez.sh --stage-retention-extend <stage-id> --days <total-days>
       soviez.sh --stage-retention-run <stage-id>
       soviez.sh --stage-retention-retry <stage-id>
       soviez.sh --stage-retention-reattach <operation-id>
       soviez.sh --ssl-status [environment-id]
       soviez.sh --ssl-renew <environment-id>
       soviez.sh --ssl-repair <environment-id>
       soviez.sh --ssl-reattach <operation-id>
       soviez.sh --ssl-policy <environment-id> [automatic|notify_only|manual]
       soviez.sh --ssl-try-again <environment-id>
       soviez.sh --ssl-abort <environment-id>
       soviez.sh --operations [--active|--failed|--environment ID|--type TYPE]
       soviez.sh --operation-status <operation-id>
       soviez.sh --operation-reattach <operation-id>
       soviez.sh --operation-cancel <operation-id>
       soviez.sh --operation-retry <operation-id>
       soviez.sh --operation-recover <operation-id>
       soviez.sh --operation-logs <operation-id>
       soviez.sh --operation-reconcile [operation-id]
       soviez.sh --backup <production-id> [--destination PROFILE] [--type full|database-only] [--advanced] [--confirm]
       soviez.sh --backup-status <operation-id>
       soviez.sh --backup-list [--production ID]
       soviez.sh --backup-show <backup-id>
       soviez.sh --backup-verify <backup-id>
       soviez.sh --backup-restore-test <backup-id>
       soviez.sh --backup-export <backup-id> --output PATH
       soviez.sh --backup-import PATH [--confirm]
       soviez.sh --backup-delete <backup-id> [--dry-run] [--confirm]
       soviez.sh --backup-pin <backup-id>
       soviez.sh --backup-unpin <backup-id>
       soviez.sh --backup-retention-status [--production ID]
       soviez.sh --backup-retention-cleanup [--production ID] [--dry-run] [--confirm]
       soviez.sh --backup-destination-list
       soviez.sh --backup-destination-show <profile-id>
       soviez.sh --backup-destination-test <profile-id>
       soviez.sh --backup-schedule-add <production-id> [--destination PROFILE]
       soviez.sh --backup-schedule-list
       soviez.sh --migration-discover <production-id>
       soviez.sh --migration-discovery-show <discovery-id>
       soviez.sh --migration-bootstrap-destination [--confirm]
       soviez.sh --migration-bootstrap-status <operation-id>
       soviez.sh --migration-bootstrap-export <bootstrap-id> --output PATH
       soviez.sh --migration-bootstrap-import PATH
       soviez.sh --migration-pair <production-id> --destination-code CODE [--confirm ...]
       soviez.sh --migration-pair-status <pair-id>
       soviez.sh --migration-pair-export <pair-id> --output PATH
       soviez.sh --migration-pair-import PATH
       soviez.sh --migration-readiness <pair-id>
       soviez.sh --migration-readiness-show <report-id>
       soviez.sh --migration-readiness-export <report-id> --output PATH
       soviez.sh --migration-readiness-import PATH
       soviez.sh --migration-stage-select <pair-id> --stage <stage-id>
       soviez.sh --migration-stage-unselect <pair-id> --stage <stage-id>
       soviez.sh --migration-abort <pair-id>
       soviez.sh --migration-domain-plan <pair-id>
       soviez.sh --migration-domain-plan-show <plan-id>
       soviez.sh --migration-dns-challenge <pair-id> [--domain FQDN]
       soviez.sh --migration-dns-challenge-create <pair-id> [--domain-plan PLAN_ID]
       soviez.sh --migration-dns-show <challenge-id>
       soviez.sh --migration-dns-challenge-verify <challenge-id>
       soviez.sh --migration-dns-try-again <challenge-id>
       soviez.sh --migration-dns-challenge-retry <pair-id>
       soviez.sh --migration-dns-abort <challenge-id>
       soviez.sh --migration-dns-challenge-abort <challenge-id>
       soviez.sh --migration-dns-instructions <challenge-id> [--output PATH]
       soviez.sh --migration-landing-prepare <pair-id>
       soviez.sh --migration-landing-status <operation-id>
       soviez.sh --migration-landing-cleanup <pair-id>
       soviez.sh --migration-tls-prepare <pair-id> [--domain FQDN]
       soviez.sh --migration-tls-status <operation-id>
       soviez.sh --migration-tls-revoke <pair-id> [--fqdn FQDN]
       soviez.sh --migration-routing-readiness <pair-id>
       soviez.sh --migration-routing-show <plan-id>
       soviez.sh --migration-domain-abort <pair-id>
       soviez.sh --migration-transfer-plan <pair-id> [--routing-plan PLAN_ID] [--profile PROFILE]
       soviez.sh --migration-transfer-plan-show <plan-id>
       soviez.sh --migration-presync <pair-id> [--transfer-plan PLAN_ID]
       soviez.sh --migration-presync-status <operation-id>
       soviez.sh --migration-transfer-start <pair-id> [--routing-plan PLAN_ID] [--confirm] [--profile PROFILE]
       soviez.sh --migration-transfer-status <operation-id>
       soviez.sh --migration-transfer-pause <operation-id>
       soviez.sh --migration-transfer-resume <operation-id>
       soviez.sh --migration-transfer-cancel <operation-id>
       soviez.sh --migration-transfer-retry <operation-id>
       soviez.sh --migration-transfer-recover <operation-id>
       soviez.sh --migration-destination-verify <operation-id>
       soviez.sh --migration-transfer-abort <operation-id>
       soviez.sh --migration-transfer-cleanup <operation-id> [--delete-staging --confirm]
       soviez.sh --migration-stage-mark-mandatory <pair-id> --stage <stage-id>
       soviez.sh --migration-stage-mark-optional <pair-id> --stage <stage-id>
       soviez.sh --migration-authorization-plan <pair-id>
       soviez.sh --migration-authorization-show <authorization-id>
       soviez.sh --migration-activate-destination <pair-id> [--confirm] [--authorization-id ID]
       soviez.sh --migration-activation-status <operation-id|authorization-id>
       soviez.sh --migration-activation-retry <pair-id>
       soviez.sh --migration-activation-recover <operation-id>
       soviez.sh --migration-source-grace-status <source-production-id>
       soviez.sh --migration-stage-rebind-status <operation-id>
       soviez.sh --migration-phase21-readiness <operation-id|authorization-id>
       soviez.sh --migration-phase21-readiness-show <report-id>
       soviez.sh --migration-authorization-export <authorization-id> [--output PATH]
       soviez.sh --migration-authorization-import PATH
       soviez.sh --migration-cutover-plan <pair-id>
       soviez.sh --migration-cutover-plan-show <plan-id>
       soviez.sh --migration-cutover-start <pair-id> [--confirm]
       soviez.sh --migration-cutover-status <operation-id>
       soviez.sh --migration-cutover-retry <operation-id>
       soviez.sh --migration-cutover-recover <operation-id>
       soviez.sh --migration-cutover-dns-show <operation-id>
       soviez.sh --migration-cutover-dns-try-again <operation-id>
       soviez.sh --migration-cutover-rollback <operation-id> [--confirm]
       soviez.sh --migration-traffic-owner-show <authorization-id>
       soviez.sh --migration-phase22-readiness <authorization-id>
       soviez.sh --migration-phase22-readiness-show <report-id>
       soviez.sh --migration-stabilization-status <cutover-id>
       soviez.sh --migration-rollback-window-close-plan <cutover-id>
       soviez.sh --migration-rollback-window-close <cutover-id> [--confirm-phrase PHRASE]
       soviez.sh --migration-rollback-window-close-status <operation-id>
       soviez.sh --migration-source-archive-plan <source-id>
       soviez.sh --migration-source-archive-start <source-id>
       soviez.sh --migration-source-archive-status <operation-id>
       soviez.sh --migration-source-archive-retry <operation-id>
       soviez.sh --migration-source-archive-recover <operation-id>
       soviez.sh --migration-source-license-finalize <operation-id>
       soviez.sh --migration-source-credentials-status <operation-id>
       soviez.sh --migration-source-runtime-suspend <operation-id>
       soviez.sh --migration-source-retirement-status <source-id>
       soviez.sh --migration-phase23-readiness <operation-id>
       soviez.sh --migration-phase23-readiness-show <report-id>
       soviez.sh --migration-status <operation-id>
       soviez.sh --migration-reattach <operation-id>
       soviez.sh --migration-cancel <operation-id>
       soviez.sh --migration-retry <operation-id>
       soviez.sh --migration-recover <operation-id>
       soviez.sh --restore <production-id> --backup <backup-id> [--confirm]
       soviez.sh --restore-status <operation-id>
       soviez.sh --restore-cancel <operation-id>
       soviez.sh --restore-retry <operation-id>
       soviez.sh --restore-recover <operation-id>
       soviez.sh --restore-rollback <operation-id> [--confirm]
       soviez.sh --restore-cleanup <operation-id> [--confirm]
       soviez.sh --restore-test <backup-id>
       soviez.sh --restore-as-stage <backup-id> --stage-domain FQDN [--confirm]

Options:
  --new                 Start a new connected activation operation
  --reattach ID         Reattach to an in-progress --new operation
  --update ID           Safe Production update (exact Production ID required)
  --release ID          Optional exact signed release id for --update
  --offline-package PATH Signed offline update package (no network)
  --confirm             Explicit confirmation (required for non-TTY / switch / cleanup)
  --update-status ID    Update operation status + rollback window
  --update-reattach ID  Reattach update operation
  --update-cancel ID    Cancel within safe boundaries
  --update-retry ID     Retry safe failed_retryable update steps
  --update-recover ID   Recover/reconcile update operation
  --update-rollback ID  Operator rollback within safety window
  --update-cleanup ID   Cleanup candidate (keeps rollback set; requires --confirm)
  --update-image-status [ --production ID ]  Soviez ERP image retention status
  --update-image-cleanup [--dry-run] [--production ID] [--confirm] Exact image cleanup
  --dry-run             Dry-run for image cleanup (no deletion)
  --operations          List unified local operations registry
  --operation-status ID Unified operation status
  --operation-reattach ID Unified reattach (delegates to command adapters)
  --operation-cancel ID Request cancellation within documented boundaries
  --operation-retry ID  Retry a retryable/failed operation
  --operation-recover ID Reconcile/recover an operation
  --operation-logs ID   Tail redacted operation logs
  --operation-reconcile [ID] Reconcile one or all operations
  --stage               Create a Stage from a managed Production
  --stage-id ID         Unique Stage identifier
  --stage-domain FQDN   Mandatory Stage domain/subdomain
  --production-tenant T Exact Production tenant id
  --stage-list          List local Stages (no entitlement required)
  --stage-status ID     Local Stage status
  --stage-start ID      Start Stage (works after entitlement expiry)
  --stage-stop ID       Stop Stage
  --stage-backup ID     Backup Stage
  --stage-drop ID       Drop Stage (explicit confirmation)
  --stage-reattach ID   Resume Stage create operation
  --stage-retention-status [ID]  Retention countdown / deadlines (local)
  --stage-retention-extend ID --days N  Set total lifetime from creation (max 60)
  --stage-retention-run ID       Run retention deletion if due (Safe Shield)
  --stage-retention-retry ID     Retry blocked retention deletion
  --stage-retention-reattach OP  Resume retention operation by id
  --days N              Total Stage lifetime days from original creation
  --yes                 Non-interactive confirm for retention extend
  --ssl-status [ID]     Local certificate health (all or exact environment)
  --ssl-renew ID        Manual/force certificate renewal
  --ssl-repair ID       Repair certificate (force renew; never stops ERP)
  --ssl-reattach OP     Reattach SSL renewal operation
  --ssl-policy ID [MODE] View or set renewal mode (does not invalidate cert)
  --ssl-try-again ID    Retry failed renewal
  --ssl-abort ID        Abort Safely (preserve current certificate)
  --offline-request     Export offline Stage authorization request
  --offline-import PATH Import signed offline Stage package and create
  --offline-bundle-inspect PATH   Inspect signed Phase 23 offline update bundle
  --offline-bundle-plan PATH|ID   Plan offline update (dry-run)
  --offline-bundle-import PATH    Import bundle into quarantine/staging
  --offline-update-apply PATH|ID  Apply offline update (Phase 15 engine reuse)
  --offline-update-status OP      Offline update operation status
  --offline-update-result-export OP  Export signed result receipt
  --offline-update-result-show FILE  Show/verify result receipt
  --offline-trust-inspect PATH    Inspect signed trust package
  --offline-trust-import PATH     Import newer signed trust package
  --offline-phase24-readiness     Legacy Phase 23→24 readiness report (informational)
  --security-status               Phase 24 security posture (STRICT_SIG / bypass / disposable)
  --security-scan                 Run secret/dist security scan gate (Phase 24)
  --security-scan-db              S3 compromise detection (DB/host/YARA/process; read-only)
  --security-quarantine-create    S4 create quarantine record
  --security-quarantine-status ID S4 quarantine status/report
  --security-quarantine-scan ID   S4 pre-boot/S3 scan in quarantine
  --security-quarantine-promote ID S4 explicit promote (never auto)
  --security-quarantine-reject ID S4 reject quarantine
  --security-update-check         S5 post-update network/PDF/DB safety gate
  --security-backup-check         S5 backup posture/integrity/restore gate
  --security-backup-retention     S5 bounded retention cleanup (owned only)
  --security-phase25-readiness    Phase 25 readiness report only (Phase 25 remains unauthorized)
  --security-check                S1 critical containment validate (fail-closed)
  --security-harden               S1 remediate existing + re-validate
  --security-report               Print last security report
  --domain DOMAIN       Public domain (Production --new or Stage)
  --activation METHOD   automatic|manual (default: automatic)
  --channel CHANNEL     Release channel (default: stable)
  --operation-id ID     Resume specific operation id
  -h, --help            Show help
EOF
}

soviez_cli_parse() {
  SOVIEZ_CLI_COMMAND=""
  SOVIEZ_CLI_OP_ID=""
  SOVIEZ_CLI_STAGE_TARGET=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --new)
        SOVIEZ_CLI_COMMAND="new"
        shift
        ;;
      --reattach)
        SOVIEZ_CLI_COMMAND="reattach"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--reattach requires operation id"
        shift 2
        ;;
      --update)
        SOVIEZ_CLI_COMMAND="update"
        if [[ -n "${2:-}" && "${2:0:2}" != "--" ]]; then
          SOVIEZ_CLI_UPDATE_TARGET="$2"
          shift 2
        else
          SOVIEZ_CLI_UPDATE_TARGET=""
          shift
        fi
        ;;
      --update-status|--update-reattach|--update-cancel|--update-retry|--update-recover|--update-rollback|--update-cleanup)
        case "$1" in
          --update-status) SOVIEZ_CLI_COMMAND="update-status" ;;
          --update-reattach) SOVIEZ_CLI_COMMAND="update-reattach" ;;
          --update-cancel) SOVIEZ_CLI_COMMAND="update-cancel" ;;
          --update-retry) SOVIEZ_CLI_COMMAND="update-retry" ;;
          --update-recover) SOVIEZ_CLI_COMMAND="update-recover" ;;
          --update-rollback) SOVIEZ_CLI_COMMAND="update-rollback" ;;
          --update-cleanup) SOVIEZ_CLI_COMMAND="update-cleanup" ;;
        esac
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires operation id"
        shift 2
        ;;
      --update-image-status)
        SOVIEZ_CLI_COMMAND="update-image-status"
        shift
        ;;
      --update-image-cleanup)
        SOVIEZ_CLI_COMMAND="update-image-cleanup"
        shift
        ;;
      --dry-run)
        SOVIEZ_CLI_DRY_RUN="1"
        shift
        ;;
      --retry)
        # Used with --update-image-cleanup --retry <op>
        SOVIEZ_CLI_COMMAND="update-image-cleanup-retry"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--retry requires operation id"
        shift 2
        ;;
      --production)
        SOVIEZ_CLI_UPDATE_TARGET="${2:-}"
        SOVIEZ_CLI_BACKUP_PRODUCTION="${2:-}"
        [[ -n "$SOVIEZ_CLI_UPDATE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--production requires id"
        shift 2
        ;;
      --destination)
        SOVIEZ_CLI_BACKUP_DESTINATION="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_DESTINATION" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--destination requires profile id"
        shift 2
        ;;
      --type)
        SOVIEZ_CLI_BACKUP_TYPE="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_TYPE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--type requires value"
        shift 2
        ;;
      --advanced)
        SOVIEZ_CLI_ADVANCED="1"
        shift
        ;;
      --yes|-y)
        SOVIEZ_CLI_YES="1"
        SOVIEZ_CLI_CONFIRM="1"
        shift
        ;;
      --output)
        SOVIEZ_CLI_BACKUP_OUTPUT="${2:-}"
        SOVIEZ_CLI_MIG_OUTPUT="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_OUTPUT" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--output requires path"
        shift 2
        ;;
      --backup)
        # Ambiguous flag: command (--backup <production-id>) vs restore option (--restore ... --backup <backup-id>)
        if [[ "$SOVIEZ_CLI_COMMAND" == "restore" || "$SOVIEZ_CLI_COMMAND" == "restore-as-stage" ]]; then
          SOVIEZ_CLI_BACKUP_ID="${2:-}"
          SOVIEZ_CLI_RESTORE_BACKUP="${2:-}"
          [[ -n "$SOVIEZ_CLI_BACKUP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--backup requires backup id"
          shift 2
        else
          SOVIEZ_CLI_COMMAND="backup"
          SOVIEZ_CLI_BACKUP_TARGET="${2:-}"
          SOVIEZ_CLI_TARGET="${2:-}"
          [[ -n "$SOVIEZ_CLI_BACKUP_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--backup requires production id"
          shift 2
        fi
        ;;
      --release)
        SOVIEZ_CLI_UPDATE_RELEASE="${2:-}"
        [[ -n "$SOVIEZ_CLI_UPDATE_RELEASE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--release requires release id"
        shift 2
        ;;
      --offline-package)
        SOVIEZ_CLI_UPDATE_OFFLINE_PACKAGE="${2:-}"
        [[ -n "$SOVIEZ_CLI_UPDATE_OFFLINE_PACKAGE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-package requires path"
        shift 2
        ;;
      --confirm)
        SOVIEZ_CLI_CONFIRM="1"
        shift
        ;;
      --confirm-phrase)
        SOVIEZ_CLI_CONFIRM_PHRASE="${2:-}"
        [[ -n "$SOVIEZ_CLI_CONFIRM_PHRASE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--confirm-phrase requires phrase"
        export SOVIEZ_CLI_CONFIRM_PHRASE
        shift 2
        ;;
      --stage)
        SOVIEZ_CLI_COMMAND="stage"
        shift
        ;;
      --stage-list)
        SOVIEZ_CLI_COMMAND="stage-list"
        shift
        ;;
      --stage-status)
        SOVIEZ_CLI_COMMAND="stage-status"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-status requires stage id"
        shift 2
        ;;
      --stage-start)
        SOVIEZ_CLI_COMMAND="stage-start"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-start requires stage id"
        shift 2
        ;;
      --stage-stop)
        SOVIEZ_CLI_COMMAND="stage-stop"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-stop requires stage id"
        shift 2
        ;;
      --stage-backup)
        SOVIEZ_CLI_COMMAND="stage-backup"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-backup requires stage id"
        shift 2
        ;;
      --stage-drop)
        SOVIEZ_CLI_COMMAND="stage-drop"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-drop requires stage id"
        shift 2
        ;;
      --stage-reattach)
        SOVIEZ_CLI_COMMAND="stage-reattach"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-reattach requires operation id"
        shift 2
        ;;
      --stage-retention-status)
        SOVIEZ_CLI_COMMAND="stage-retention-status"
        if [[ -n "${2:-}" && "${2:0:2}" != "--" ]]; then
          SOVIEZ_CLI_STAGE_TARGET="$2"
          shift 2
        else
          shift
        fi
        ;;
      --stage-retention-extend)
        SOVIEZ_CLI_COMMAND="stage-retention-extend"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-retention-extend requires stage id"
        shift 2
        ;;
      --stage-retention-run)
        SOVIEZ_CLI_COMMAND="stage-retention-run"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-retention-run requires stage id"
        shift 2
        ;;
      --stage-retention-retry)
        SOVIEZ_CLI_COMMAND="stage-retention-retry"
        SOVIEZ_CLI_STAGE_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_STAGE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-retention-retry requires stage id"
        shift 2
        ;;
      --stage-retention-reattach)
        SOVIEZ_CLI_COMMAND="stage-retention-reattach"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-retention-reattach requires operation id"
        shift 2
        ;;
      --days)
        SOVIEZ_CLI_RETENTION_DAYS="${2:-}"
        [[ -n "$SOVIEZ_CLI_RETENTION_DAYS" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--days requires integer"
        shift 2
        ;;
      --yes)
        SOVIEZ_CLI_RETENTION_YES="--yes"
        SOVIEZ_CLI_YES="1"
        SOVIEZ_CLI_CONFIRM="1"
        shift
        ;;
      --stage-id)
        SOVIEZ_CLI_STAGE_ID="${2:-}"
        shift 2
        ;;
      --stage-domain)
        SOVIEZ_CLI_STAGE_DOMAIN="${2:-}"
        shift 2
        ;;
      --production-tenant)
        SOVIEZ_CLI_PRODUCTION_TENANT="${2:-}"
        shift 2
        ;;
      --offline-request)
        SOVIEZ_CLI_OFFLINE_MODE="request"
        shift
        ;;
      --offline-import)
        SOVIEZ_CLI_OFFLINE_MODE="import"
        SOVIEZ_CLI_OFFLINE_PACKAGE="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_PACKAGE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-import requires package path"
        shift 2
        ;;
      --offline-bundle-inspect)
        SOVIEZ_CLI_COMMAND="offline-bundle-inspect"
        SOVIEZ_CLI_OFFLINE_BUNDLE_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_BUNDLE_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-bundle-inspect requires path"
        shift 2
        ;;
      --offline-bundle-plan)
        SOVIEZ_CLI_COMMAND="offline-bundle-plan"
        SOVIEZ_CLI_OFFLINE_BUNDLE_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_BUNDLE_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-bundle-plan requires path or id"
        shift 2
        ;;
      --offline-bundle-import)
        SOVIEZ_CLI_COMMAND="offline-bundle-import"
        SOVIEZ_CLI_OFFLINE_BUNDLE_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_BUNDLE_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-bundle-import requires path"
        shift 2
        ;;
      --offline-update-apply)
        SOVIEZ_CLI_COMMAND="offline-update-apply"
        SOVIEZ_CLI_OFFLINE_BUNDLE_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_BUNDLE_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-update-apply requires path or id"
        shift 2
        ;;
      --offline-update-status)
        SOVIEZ_CLI_COMMAND="offline-update-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-update-status requires operation id"
        shift 2
        ;;
      --offline-update-result-export)
        SOVIEZ_CLI_COMMAND="offline-update-result-export"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-update-result-export requires operation id"
        shift 2
        ;;
      --offline-update-result-show)
        SOVIEZ_CLI_COMMAND="offline-update-result-show"
        SOVIEZ_CLI_OFFLINE_RECEIPT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_RECEIPT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-update-result-show requires receipt path"
        shift 2
        ;;
      --offline-trust-inspect)
        SOVIEZ_CLI_COMMAND="offline-trust-inspect"
        SOVIEZ_CLI_OFFLINE_TRUST_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_TRUST_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-trust-inspect requires path"
        shift 2
        ;;
      --offline-trust-import)
        SOVIEZ_CLI_COMMAND="offline-trust-import"
        SOVIEZ_CLI_OFFLINE_TRUST_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_OFFLINE_TRUST_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--offline-trust-import requires path"
        shift 2
        ;;
      --offline-phase24-readiness)
        SOVIEZ_CLI_COMMAND="offline-phase24-readiness"
        shift
        ;;
      --security-status)
        SOVIEZ_CLI_COMMAND="security-status"
        shift
        ;;
      --security-scan)
        SOVIEZ_CLI_COMMAND="security-scan"
        shift
        ;;
      --security-scan-db)
        SOVIEZ_CLI_COMMAND="security-scan-db"
        shift
        ;;
      --security-quarantine-create)
        SOVIEZ_CLI_COMMAND="security-quarantine-create"
        shift
        ;;
      --security-quarantine-status)
        SOVIEZ_CLI_COMMAND="security-quarantine-status"
        SOVIEZ_CLI_Q_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_Q_ID" && "${SOVIEZ_CLI_Q_ID:0:2}" != "--" ]] && shift 2 || shift
        ;;
      --security-quarantine-scan)
        SOVIEZ_CLI_COMMAND="security-quarantine-scan"
        SOVIEZ_CLI_Q_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_Q_ID" && "${SOVIEZ_CLI_Q_ID:0:2}" != "--" ]] && shift 2 || shift
        ;;
      --security-quarantine-promote)
        SOVIEZ_CLI_COMMAND="security-quarantine-promote"
        SOVIEZ_CLI_Q_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_Q_ID" && "${SOVIEZ_CLI_Q_ID:0:2}" != "--" ]] && shift 2 || shift
        ;;
      --security-quarantine-reject)
        SOVIEZ_CLI_COMMAND="security-quarantine-reject"
        SOVIEZ_CLI_Q_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_Q_ID" && "${SOVIEZ_CLI_Q_ID:0:2}" != "--" ]] && shift 2 || shift
        ;;
      --security-quarantine-accept-review)
        SOVIEZ_CLI_COMMAND="security-quarantine-accept-review"
        SOVIEZ_CLI_Q_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_Q_ID" && "${SOVIEZ_CLI_Q_ID:0:2}" != "--" ]] && shift 2 || shift
        ;;
      --security-update-check)
        SOVIEZ_CLI_COMMAND="security-update-check"
        shift
        ;;
      --security-backup-check)
        SOVIEZ_CLI_COMMAND="security-backup-check"
        shift
        ;;
      --security-backup-retention)
        SOVIEZ_CLI_COMMAND="security-backup-retention"
        shift
        ;;
      --security-phase25-readiness)
        SOVIEZ_CLI_COMMAND="security-phase25-readiness"
        shift
        ;;
      --security-check)
        SOVIEZ_CLI_COMMAND="security-check"
        shift
        ;;
      --security-harden)
        SOVIEZ_CLI_COMMAND="security-harden"
        shift
        ;;
      --security-report)
        SOVIEZ_CLI_COMMAND="security-report"
        shift
        ;;
      --license-id)
        SOVIEZ_CLI_LICENSE_ID="${2:-}"
        export SOVIEZ_LICENSE_ID="$SOVIEZ_CLI_LICENSE_ID"
        shift 2
        ;;
      --environment-id)
        SOVIEZ_CLI_ENVIRONMENT_ID="${2:-}"
        export SOVIEZ_ENVIRONMENT_ID="$SOVIEZ_CLI_ENVIRONMENT_ID"
        shift 2
        ;;
      --device-fingerprint)
        SOVIEZ_CLI_DEVICE_FINGERPRINT="${2:-}"
        export SOVIEZ_DEVICE_FINGERPRINT="$SOVIEZ_CLI_DEVICE_FINGERPRINT"
        shift 2
        ;;
      --confirm-text)
        SOVIEZ_CLI_CONFIRM_TEXT="${2:-}"
        shift 2
        ;;
      --domain)
        SOVIEZ_CLI_DOMAIN="${2:-}"
        shift 2
        ;;
      --activation)
        SOVIEZ_CLI_ACTIVATION_METHOD="${2:-automatic}"
        shift 2
        ;;
      --channel)
        SOVIEZ_CLI_CHANNEL="${2:-stable}"
        shift 2
        ;;
      --operation-id)
        SOVIEZ_CLI_OP_ID="${2:-}"
        shift 2
        ;;
      --ssl-status)
        SOVIEZ_CLI_COMMAND="ssl-status"
        if [[ -n "${2:-}" && "${2:0:2}" != "--" ]]; then
          SOVIEZ_CLI_SSL_TARGET="$2"
          shift 2
        else
          shift
        fi
        ;;
      --ssl-renew)
        SOVIEZ_CLI_COMMAND="ssl-renew"
        SOVIEZ_CLI_SSL_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_SSL_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-renew requires environment id"
        shift 2
        ;;
      --ssl-repair)
        SOVIEZ_CLI_COMMAND="ssl-repair"
        SOVIEZ_CLI_SSL_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_SSL_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-repair requires environment id"
        shift 2
        ;;
      --ssl-reattach)
        SOVIEZ_CLI_COMMAND="ssl-reattach"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-reattach requires operation id"
        shift 2
        ;;
      --ssl-policy)
        SOVIEZ_CLI_COMMAND="ssl-policy"
        SOVIEZ_CLI_SSL_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_SSL_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-policy requires environment id"
        shift 2
        if [[ -n "${1:-}" && "${1:0:2}" != "--" ]]; then
          SOVIEZ_CLI_SSL_POLICY_MODE="$1"
          shift
        fi
        ;;
      --ssl-try-again)
        SOVIEZ_CLI_COMMAND="ssl-try-again"
        SOVIEZ_CLI_SSL_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_SSL_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-try-again requires environment id"
        shift 2
        ;;
      --ssl-abort)
        SOVIEZ_CLI_COMMAND="ssl-abort"
        SOVIEZ_CLI_SSL_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_SSL_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--ssl-abort requires environment id"
        shift 2
        ;;
      --operations)
        SOVIEZ_CLI_COMMAND="operations-list"
        SOVIEZ_CLI_OPS_FILTER=""
        SOVIEZ_CLI_OPS_FILTER_VALUE=""
        shift
        while [[ $# -gt 0 && "${1:0:2}" == "--" ]]; do
          case "$1" in
            --active|--failed) SOVIEZ_CLI_OPS_FILTER="$1"; shift ;;
            --environment|--type)
              SOVIEZ_CLI_OPS_FILTER="$1"
              SOVIEZ_CLI_OPS_FILTER_VALUE="${2:-}"
              [[ -n "$SOVIEZ_CLI_OPS_FILTER_VALUE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires a value"
              shift 2
              ;;
            *) break ;;
          esac
        done
        ;;
      --operations-list) SOVIEZ_CLI_COMMAND="operations-list"; shift ;;
      --operation-status|--operation-reattach|--operation-cancel|--operation-retry|--operation-recover|--operation-logs)
        case "$1" in
          --operation-status) SOVIEZ_CLI_COMMAND="operation-status" ;;
          --operation-reattach) SOVIEZ_CLI_COMMAND="operation-reattach" ;;
          --operation-cancel) SOVIEZ_CLI_COMMAND="operation-cancel" ;;
          --operation-retry) SOVIEZ_CLI_COMMAND="operation-retry" ;;
          --operation-recover) SOVIEZ_CLI_COMMAND="operation-recover" ;;
          --operation-logs) SOVIEZ_CLI_COMMAND="operation-logs" ;;
        esac
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires operation id"
        shift 2
        ;;
      --operation-reconcile)
        SOVIEZ_CLI_COMMAND="operation-reconcile"
        if [[ -n "${2:-}" && "${2:0:2}" != "--" ]]; then
          SOVIEZ_CLI_OP_ID="$2"
          shift 2
        else
          SOVIEZ_CLI_OP_ID=""
          shift
        fi
        ;;
      --backup-status|--backup-show|--backup-verify|--backup-restore-test|--backup-pin|--backup-unpin|--backup-delete|--backup-export)
        case "$1" in
          --backup-status) SOVIEZ_CLI_COMMAND="backup-status" ;;
          --backup-show) SOVIEZ_CLI_COMMAND="backup-show" ;;
          --backup-verify) SOVIEZ_CLI_COMMAND="backup-verify" ;;
          --backup-restore-test) SOVIEZ_CLI_COMMAND="backup-restore-test" ;;
          --backup-pin) SOVIEZ_CLI_COMMAND="backup-pin" ;;
          --backup-unpin) SOVIEZ_CLI_COMMAND="backup-unpin" ;;
          --backup-delete) SOVIEZ_CLI_COMMAND="backup-delete" ;;
          --backup-export) SOVIEZ_CLI_COMMAND="backup-export" ;;
        esac
        if [[ "$SOVIEZ_CLI_COMMAND" == "backup-status" ]]; then
          SOVIEZ_CLI_OP_ID="${2:-}"
          [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires operation id"
        else
          SOVIEZ_CLI_BACKUP_ID="${2:-}"
          [[ -n "$SOVIEZ_CLI_BACKUP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires backup id"
        fi
        shift 2
        ;;
      --backup-list)
        SOVIEZ_CLI_COMMAND="backup-list"
        shift
        ;;
      --backup-import)
        SOVIEZ_CLI_COMMAND="backup-import"
        SOVIEZ_CLI_BACKUP_IMPORT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_IMPORT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--backup-import requires path"
        shift 2
        ;;
      --backup-retention-status)
        SOVIEZ_CLI_COMMAND="backup-retention-status"
        shift
        ;;
      --backup-retention-cleanup)
        SOVIEZ_CLI_COMMAND="backup-retention-cleanup"
        SOVIEZ_CLI_BACKUP_RETENTION_EXECUTE="1"
        shift
        ;;
      --backup-destination-list)
        SOVIEZ_CLI_COMMAND="backup-destination-list"
        shift
        ;;
      --backup-destination-show|--backup-destination-test)
        case "$1" in
          --backup-destination-show) SOVIEZ_CLI_COMMAND="backup-destination-show" ;;
          --backup-destination-test) SOVIEZ_CLI_COMMAND="backup-destination-test" ;;
        esac
        SOVIEZ_CLI_BACKUP_DESTINATION="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_DESTINATION" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires profile id"
        shift 2
        ;;
      --backup-schedule-list)
        SOVIEZ_CLI_COMMAND="backup-schedule-list"
        shift
        ;;
      --backup-schedule-add)
        SOVIEZ_CLI_COMMAND="backup-schedule-add"
        SOVIEZ_CLI_BACKUP_TARGET="${2:-}"
        SOVIEZ_CLI_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--backup-schedule-add requires production id"
        shift 2
        ;;
      --restore)
        SOVIEZ_CLI_COMMAND="restore"
        SOVIEZ_CLI_RESTORE_TARGET="${2:-}"
        SOVIEZ_CLI_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_RESTORE_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--restore requires production id"
        shift 2
        ;;
      --restore-status|--restore-cancel|--restore-retry|--restore-recover|--restore-rollback|--restore-cleanup)
        case "$1" in
          --restore-status) SOVIEZ_CLI_COMMAND="restore-status" ;;
          --restore-cancel) SOVIEZ_CLI_COMMAND="restore-cancel" ;;
          --restore-retry) SOVIEZ_CLI_COMMAND="restore-retry" ;;
          --restore-recover) SOVIEZ_CLI_COMMAND="restore-recover" ;;
          --restore-rollback) SOVIEZ_CLI_COMMAND="restore-rollback" ;;
          --restore-cleanup) SOVIEZ_CLI_COMMAND="restore-cleanup" ;;
        esac
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires operation id"
        shift 2
        ;;
      --restore-test)
        SOVIEZ_CLI_COMMAND="restore-test"
        SOVIEZ_CLI_BACKUP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--restore-test requires backup id"
        shift 2
        ;;
      --restore-as-stage)
        SOVIEZ_CLI_COMMAND="restore-as-stage"
        SOVIEZ_CLI_BACKUP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_BACKUP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--restore-as-stage requires backup id"
        shift 2
        ;;
      --destination-code)
        SOVIEZ_CLI_MIG_DEST_CODE="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_DEST_CODE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--destination-code requires code"
        shift 2
        ;;
      --confirm-source-fp)
        SOVIEZ_CLI_MIG_CONFIRM_SRC_FP="${2:-}"
        shift 2
        ;;
      --confirm-destination-fp)
        SOVIEZ_CLI_MIG_CONFIRM_DST_FP="${2:-}"
        shift 2
        ;;
      --confirm-license)
        SOVIEZ_CLI_MIG_CONFIRM_LICENSE="${2:-}"
        shift 2
        ;;
      --confirm-production)
        SOVIEZ_CLI_MIG_CONFIRM_PROD="${2:-}"
        shift 2
        ;;
      --confirm-bootstrap)
        SOVIEZ_CLI_MIG_CONFIRM_BOOT="${2:-}"
        shift 2
        ;;
      --stage)
        SOVIEZ_CLI_MIG_STAGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_STAGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage requires stage id"
        shift 2
        ;;
      --migration-discover)
        SOVIEZ_CLI_COMMAND="migration-discover"
        SOVIEZ_CLI_MIG_TARGET="${2:-}"
        SOVIEZ_CLI_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-discover requires production id"
        shift 2
        ;;
      --migration-discovery-show)
        SOVIEZ_CLI_COMMAND="migration-discovery-show"
        SOVIEZ_CLI_MIG_DISCOVERY_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_DISCOVERY_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-discovery-show requires discovery id"
        shift 2
        ;;
      --migration-bootstrap-destination)
        SOVIEZ_CLI_COMMAND="migration-bootstrap-destination"
        shift
        ;;
      --migration-bootstrap-status)
        SOVIEZ_CLI_COMMAND="migration-bootstrap-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-bootstrap-status requires operation id"
        shift 2
        ;;
      --migration-bootstrap-export)
        SOVIEZ_CLI_COMMAND="migration-bootstrap-export"
        SOVIEZ_CLI_MIG_BOOTSTRAP_ID="${2:-}"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_BOOTSTRAP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-bootstrap-export requires bootstrap id"
        shift 2
        ;;
      --migration-bootstrap-import)
        SOVIEZ_CLI_COMMAND="migration-bootstrap-import"
        SOVIEZ_CLI_MIG_IMPORT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_IMPORT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-bootstrap-import requires path"
        shift 2
        ;;
      --migration-pair)
        SOVIEZ_CLI_COMMAND="migration-pair"
        SOVIEZ_CLI_MIG_TARGET="${2:-}"
        SOVIEZ_CLI_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-pair requires production id"
        shift 2
        ;;
      --migration-pair-status)
        SOVIEZ_CLI_COMMAND="migration-pair-status"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-pair-status requires pair id"
        shift 2
        ;;
      --migration-pair-export)
        SOVIEZ_CLI_COMMAND="migration-pair-export"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-pair-export requires pair id"
        shift 2
        ;;
      --migration-pair-import)
        SOVIEZ_CLI_COMMAND="migration-pair-import"
        SOVIEZ_CLI_MIG_IMPORT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_IMPORT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-pair-import requires path"
        shift 2
        ;;
      --migration-readiness)
        SOVIEZ_CLI_COMMAND="migration-readiness"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-readiness requires pair id"
        shift 2
        ;;
      --migration-readiness-show)
        SOVIEZ_CLI_COMMAND="migration-readiness-show"
        SOVIEZ_CLI_MIG_REPORT_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_REPORT_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-readiness-show requires report id"
        shift 2
        ;;
      --migration-readiness-export)
        SOVIEZ_CLI_COMMAND="migration-readiness-export"
        SOVIEZ_CLI_MIG_REPORT_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_REPORT_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-readiness-export requires report id"
        shift 2
        ;;
      --migration-readiness-import)
        SOVIEZ_CLI_COMMAND="migration-readiness-import"
        SOVIEZ_CLI_MIG_IMPORT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_IMPORT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-readiness-import requires path"
        shift 2
        ;;
      --migration-stage-select)
        SOVIEZ_CLI_COMMAND="migration-stage-select"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stage-select requires pair id"
        shift 2
        ;;
      --migration-stage-unselect)
        SOVIEZ_CLI_COMMAND="migration-stage-unselect"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stage-unselect requires pair id"
        shift 2
        ;;
      --migration-abort)
        SOVIEZ_CLI_COMMAND="migration-abort"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-abort requires pair id"
        shift 2
        ;;
      --migration-domain-plan)
        SOVIEZ_CLI_COMMAND="migration-domain-plan"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-domain-plan requires pair id"
        shift 2
        ;;
      --migration-domain-plan-show)
        SOVIEZ_CLI_COMMAND="migration-domain-plan-show"
        SOVIEZ_CLI_MIG_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-domain-plan-show requires plan id"
        shift 2
        ;;
      --migration-dns-challenge-create|--migration-dns-challenge)
        SOVIEZ_CLI_COMMAND="migration-dns-challenge-create"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-challenge requires pair id"
        shift 2
        ;;
      --migration-dns-challenge-verify)
        SOVIEZ_CLI_COMMAND="migration-dns-challenge-verify"
        SOVIEZ_CLI_MIG_CHALLENGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_CHALLENGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-challenge-verify requires challenge id"
        shift 2
        ;;
      --migration-dns-show)
        SOVIEZ_CLI_COMMAND="migration-dns-show"
        SOVIEZ_CLI_MIG_CHALLENGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_CHALLENGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-show requires challenge id"
        shift 2
        ;;
      --migration-dns-challenge-abort|--migration-dns-abort)
        SOVIEZ_CLI_COMMAND="migration-dns-challenge-abort"
        SOVIEZ_CLI_MIG_CHALLENGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_CHALLENGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-abort requires challenge id"
        shift 2
        ;;
      --migration-dns-challenge-retry)
        SOVIEZ_CLI_COMMAND="migration-dns-challenge-retry"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-challenge-retry requires pair id"
        shift 2
        ;;
      --migration-dns-try-again)
        SOVIEZ_CLI_COMMAND="migration-dns-try-again"
        SOVIEZ_CLI_MIG_CHALLENGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_CHALLENGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-try-again requires challenge id"
        shift 2
        ;;
      --migration-dns-instructions)
        SOVIEZ_CLI_COMMAND="migration-dns-instructions"
        SOVIEZ_CLI_MIG_CHALLENGE_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_CHALLENGE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-dns-instructions requires challenge id"
        shift 2
        ;;
      --migration-landing-prepare)
        SOVIEZ_CLI_COMMAND="migration-landing-prepare"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-landing-prepare requires pair id"
        shift 2
        ;;
      --migration-landing-status)
        SOVIEZ_CLI_COMMAND="migration-landing-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-landing-status requires operation id"
        shift 2
        ;;
      --migration-landing-cleanup)
        SOVIEZ_CLI_COMMAND="migration-landing-cleanup"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-landing-cleanup requires pair id"
        shift 2
        ;;
      --migration-tls-prepare)
        SOVIEZ_CLI_COMMAND="migration-tls-prepare"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-tls-prepare requires pair id"
        shift 2
        ;;
      --migration-tls-status)
        SOVIEZ_CLI_COMMAND="migration-tls-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-tls-status requires operation id"
        shift 2
        ;;
      --migration-tls-revoke)
        SOVIEZ_CLI_COMMAND="migration-tls-revoke"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-tls-revoke requires pair id"
        shift 2
        ;;
      --migration-routing-readiness)
        SOVIEZ_CLI_COMMAND="migration-routing-readiness"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-routing-readiness requires pair id"
        shift 2
        ;;
      --migration-routing-show)
        SOVIEZ_CLI_COMMAND="migration-routing-show"
        SOVIEZ_CLI_MIG_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-routing-show requires plan id"
        shift 2
        ;;
      --migration-domain-abort)
        SOVIEZ_CLI_COMMAND="migration-domain-abort"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-domain-abort requires pair id"
        shift 2
        ;;
      --routing-plan)
        SOVIEZ_CLI_MIG_ROUTING_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_ROUTING_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--routing-plan requires plan id"
        shift 2
        ;;
      --transfer-plan)
        SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--transfer-plan requires plan id"
        shift 2
        ;;
      --profile)
        SOVIEZ_CLI_MIG_PROFILE="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PROFILE" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--profile requires value"
        case "$SOVIEZ_CLI_MIG_PROFILE" in
          conservative|balanced|fast) ;;
          *) soviez_die "$SOVIEZ_ERR_USAGE" "--profile must be conservative|balanced|fast" ;;
        esac
        shift 2
        ;;
      --delete-staging)
        SOVIEZ_CLI_MIG_DELETE_STAGING=1
        shift
        ;;
      --migration-transfer-plan)
        SOVIEZ_CLI_COMMAND="migration-transfer-plan"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-plan requires pair id"
        shift 2
        ;;
      --migration-transfer-plan-show)
        SOVIEZ_CLI_COMMAND="migration-transfer-plan-show"
        SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID="${2:-}"
        SOVIEZ_CLI_MIG_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_TRANSFER_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-plan-show requires plan id"
        shift 2
        ;;
      --migration-presync)
        SOVIEZ_CLI_COMMAND="migration-presync"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-presync requires pair id"
        shift 2
        ;;
      --migration-presync-status)
        SOVIEZ_CLI_COMMAND="migration-presync-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-presync-status requires operation id"
        shift 2
        ;;
      --migration-transfer-start)
        SOVIEZ_CLI_COMMAND="migration-transfer-start"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-start requires pair id"
        shift 2
        ;;
      --migration-transfer-status)
        SOVIEZ_CLI_COMMAND="migration-transfer-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-status requires operation id"
        shift 2
        ;;
      --migration-transfer-pause)
        SOVIEZ_CLI_COMMAND="migration-transfer-pause"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-pause requires operation id"
        shift 2
        ;;
      --migration-transfer-resume)
        SOVIEZ_CLI_COMMAND="migration-transfer-resume"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-resume requires operation id"
        shift 2
        ;;
      --migration-transfer-cancel)
        SOVIEZ_CLI_COMMAND="migration-transfer-cancel"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-cancel requires operation id"
        shift 2
        ;;
      --migration-transfer-retry)
        SOVIEZ_CLI_COMMAND="migration-transfer-retry"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-retry requires operation id"
        shift 2
        ;;
      --migration-transfer-recover)
        SOVIEZ_CLI_COMMAND="migration-transfer-recover"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-recover requires operation id"
        shift 2
        ;;
      --migration-destination-verify)
        SOVIEZ_CLI_COMMAND="migration-destination-verify"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-destination-verify requires operation id"
        shift 2
        ;;
      --migration-transfer-abort)
        SOVIEZ_CLI_COMMAND="migration-transfer-abort"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-abort requires operation id"
        shift 2
        ;;
      --migration-transfer-cleanup)
        SOVIEZ_CLI_COMMAND="migration-transfer-cleanup"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-transfer-cleanup requires operation id"
        shift 2
        ;;
      --migration-stage-mark-mandatory)
        SOVIEZ_CLI_COMMAND="migration-stage-mark-mandatory"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stage-mark-mandatory requires pair id"
        shift 2
        ;;
      --migration-stage-mark-optional)
        SOVIEZ_CLI_COMMAND="migration-stage-mark-optional"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stage-mark-optional requires pair id"
        shift 2
        ;;
      --authorization-id)
        SOVIEZ_CLI_MIG_AUTH_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_AUTH_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--authorization-id requires id"
        shift 2
        ;;
      --migration-authorization-plan)
        SOVIEZ_CLI_COMMAND="migration-authorization-plan"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-authorization-plan requires pair id"
        shift 2
        ;;
      --migration-authorization-show)
        SOVIEZ_CLI_COMMAND="migration-authorization-show"
        SOVIEZ_CLI_MIG_AUTH_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_AUTH_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-authorization-show requires authorization id"
        shift 2
        ;;
      --migration-activate-destination)
        SOVIEZ_CLI_COMMAND="migration-activate-destination"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-activate-destination requires pair id"
        shift 2
        ;;
      --migration-activation-status)
        SOVIEZ_CLI_COMMAND="migration-activation-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-activation-status requires id"
        shift 2
        ;;
      --migration-activation-retry)
        SOVIEZ_CLI_COMMAND="migration-activation-retry"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-activation-retry requires pair id"
        shift 2
        ;;
      --migration-activation-recover)
        SOVIEZ_CLI_COMMAND="migration-activation-recover"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-activation-recover requires operation id"
        shift 2
        ;;
      --migration-source-grace-status)
        SOVIEZ_CLI_COMMAND="migration-source-grace-status"
        SOVIEZ_CLI_MIG_TARGET="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_TARGET" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-grace-status requires source production id"
        shift 2
        ;;
      --migration-stage-rebind-status)
        SOVIEZ_CLI_COMMAND="migration-stage-rebind-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stage-rebind-status requires operation id"
        shift 2
        ;;
      --migration-phase21-readiness)
        SOVIEZ_CLI_COMMAND="migration-phase21-readiness"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase21-readiness requires id"
        shift 2
        ;;
      --migration-phase21-readiness-show)
        SOVIEZ_CLI_COMMAND="migration-phase21-readiness-show"
        SOVIEZ_CLI_MIG_REPORT_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_REPORT_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase21-readiness-show requires report id"
        shift 2
        ;;
      --migration-authorization-export)
        SOVIEZ_CLI_COMMAND="migration-authorization-export"
        SOVIEZ_CLI_MIG_AUTH_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_AUTH_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-authorization-export requires authorization id"
        shift 2
        ;;
      --migration-authorization-import)
        SOVIEZ_CLI_COMMAND="migration-authorization-import"
        SOVIEZ_CLI_MIG_IMPORT_PATH="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_IMPORT_PATH" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-authorization-import requires path"
        shift 2
        ;;
      --migration-cutover-plan)
        SOVIEZ_CLI_COMMAND="migration-cutover-plan"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-plan requires pair id"
        shift 2
        ;;
      --migration-cutover-plan-show)
        SOVIEZ_CLI_COMMAND="migration-cutover-plan-show"
        SOVIEZ_CLI_MIG_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-plan-show requires plan id"
        shift 2
        ;;
      --migration-cutover-start)
        SOVIEZ_CLI_COMMAND="migration-cutover-start"
        SOVIEZ_CLI_MIG_PAIR_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PAIR_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-start requires pair id"
        shift 2
        ;;
      --migration-cutover-status)
        SOVIEZ_CLI_COMMAND="migration-cutover-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-status requires operation id"
        shift 2
        ;;
      --migration-cutover-retry)
        SOVIEZ_CLI_COMMAND="migration-cutover-retry"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-retry requires operation id"
        shift 2
        ;;
      --migration-cutover-recover)
        SOVIEZ_CLI_COMMAND="migration-cutover-recover"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-recover requires operation id"
        shift 2
        ;;
      --migration-cutover-dns-show)
        SOVIEZ_CLI_COMMAND="migration-cutover-dns-show"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-dns-show requires operation id"
        shift 2
        ;;
      --migration-cutover-dns-try-again)
        SOVIEZ_CLI_COMMAND="migration-cutover-dns-try-again"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-dns-try-again requires operation id"
        shift 2
        ;;
      --migration-cutover-rollback)
        SOVIEZ_CLI_COMMAND="migration-cutover-rollback"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-cutover-rollback requires operation id"
        shift 2
        ;;
      --migration-traffic-owner-show)
        SOVIEZ_CLI_COMMAND="migration-traffic-owner-show"
        SOVIEZ_CLI_MIG_AUTH_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_AUTH_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-traffic-owner-show requires authorization id"
        shift 2
        ;;
      --migration-phase22-readiness)
        SOVIEZ_CLI_COMMAND="migration-phase22-readiness"
        SOVIEZ_CLI_MIG_AUTH_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_AUTH_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase22-readiness requires authorization id"
        shift 2
        ;;
      --migration-phase22-readiness-show)
        SOVIEZ_CLI_COMMAND="migration-phase22-readiness-show"
        SOVIEZ_CLI_MIG_REPORT_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_REPORT_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase22-readiness-show requires report id"
        shift 2
        ;;
      --migration-stabilization-status)
        SOVIEZ_CLI_COMMAND="migration-stabilization-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        SOVIEZ_CLI_MIG_CUTOVER_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-stabilization-status requires cutover id"
        shift 2
        ;;
      --migration-rollback-window-close-plan)
        SOVIEZ_CLI_COMMAND="migration-rollback-window-close-plan"
        SOVIEZ_CLI_OP_ID="${2:-}"
        SOVIEZ_CLI_MIG_CUTOVER_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-rollback-window-close-plan requires cutover id"
        shift 2
        ;;
      --migration-rollback-window-close)
        SOVIEZ_CLI_COMMAND="migration-rollback-window-close"
        SOVIEZ_CLI_OP_ID="${2:-}"
        SOVIEZ_CLI_MIG_CUTOVER_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-rollback-window-close requires cutover id"
        shift 2
        ;;
      --migration-rollback-window-close-status)
        SOVIEZ_CLI_COMMAND="migration-rollback-window-close-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-rollback-window-close-status requires operation id"
        shift 2
        ;;
      --migration-source-archive-plan)
        SOVIEZ_CLI_COMMAND="migration-source-archive-plan"
        SOVIEZ_CLI_MIG_SOURCE_ID="${2:-}"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_SOURCE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-archive-plan requires source id"
        shift 2
        ;;
      --migration-source-archive-start)
        SOVIEZ_CLI_COMMAND="migration-source-archive-start"
        SOVIEZ_CLI_MIG_SOURCE_ID="${2:-}"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_SOURCE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-archive-start requires source id"
        shift 2
        ;;
      --migration-source-archive-status)
        SOVIEZ_CLI_COMMAND="migration-source-archive-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-archive-status requires operation id"
        shift 2
        ;;
      --migration-source-archive-retry)
        SOVIEZ_CLI_COMMAND="migration-source-archive-retry"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-archive-retry requires operation id"
        shift 2
        ;;
      --migration-source-archive-recover)
        SOVIEZ_CLI_COMMAND="migration-source-archive-recover"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-archive-recover requires operation id"
        shift 2
        ;;
      --migration-source-license-finalize)
        SOVIEZ_CLI_COMMAND="migration-source-license-finalize"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-license-finalize requires operation id"
        shift 2
        ;;
      --migration-source-credentials-status)
        SOVIEZ_CLI_COMMAND="migration-source-credentials-status"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-credentials-status requires operation id"
        shift 2
        ;;
      --migration-source-runtime-suspend)
        SOVIEZ_CLI_COMMAND="migration-source-runtime-suspend"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-runtime-suspend requires operation id"
        shift 2
        ;;
      --migration-source-retirement-status)
        SOVIEZ_CLI_COMMAND="migration-source-retirement-status"
        SOVIEZ_CLI_MIG_SOURCE_ID="${2:-}"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_SOURCE_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-source-retirement-status requires source id"
        shift 2
        ;;
      --migration-phase23-readiness)
        SOVIEZ_CLI_COMMAND="migration-phase23-readiness"
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase23-readiness requires operation id"
        shift 2
        ;;
      --migration-phase23-readiness-show)
        SOVIEZ_CLI_COMMAND="migration-phase23-readiness-show"
        SOVIEZ_CLI_MIG_REPORT_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_REPORT_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--migration-phase23-readiness-show requires report id"
        shift 2
        ;;
      --domain-plan)
        SOVIEZ_CLI_MIG_PLAN_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_PLAN_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--domain-plan requires plan id"
        shift 2
        ;;
      --domain|--fqdn)
        SOVIEZ_CLI_MIG_FQDN="${2:-}"
        [[ -n "$SOVIEZ_CLI_MIG_FQDN" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--domain/--fqdn requires value"
        shift 2
        ;;
      --migration-status|--migration-reattach|--migration-cancel|--migration-retry|--migration-recover)
        case "$1" in
          --migration-status) SOVIEZ_CLI_COMMAND="migration-status" ;;
          --migration-reattach) SOVIEZ_CLI_COMMAND="migration-reattach" ;;
          --migration-cancel) SOVIEZ_CLI_COMMAND="migration-cancel" ;;
          --migration-retry) SOVIEZ_CLI_COMMAND="migration-retry" ;;
          --migration-recover) SOVIEZ_CLI_COMMAND="migration-recover" ;;
        esac
        SOVIEZ_CLI_OP_ID="${2:-}"
        [[ -n "$SOVIEZ_CLI_OP_ID" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "$1 requires operation id"
        shift 2
        ;;
      -h|--help)
        soviez_cli_usage
        exit 0
        ;;
      *)
        soviez_die "$SOVIEZ_ERR_USAGE" "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$SOVIEZ_CLI_COMMAND" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "Specify a command (see --help)"
  if [[ "$SOVIEZ_CLI_COMMAND" == "stage-retention-extend" ]]; then
    [[ -n "${SOVIEZ_CLI_RETENTION_DAYS:-}" ]] || soviez_die "$SOVIEZ_ERR_USAGE" "--stage-retention-extend requires --days <total-days>"
  fi
}
