# shellcheck shell=bash
# Security Gate S3 — DB record context helpers.

soviez_s3_db_model_alias() {
  case "$1" in
    ir_act_server) printf '%s\n' "ir.actions.server" ;;
    ir_config_parameter) printf '%s\n' "ir.config_parameter" ;;
    ir_ui_view) printf '%s\n' "ir.ui.view" ;;
    ir_cron) printf '%s\n' "ir.cron" ;;
    base_automation) printf '%s\n' "base.automation" ;;
    *) printf '%s\n' "$1" ;;
  esac
}
