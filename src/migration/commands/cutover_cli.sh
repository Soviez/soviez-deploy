# shellcheck shell=bash
# Phase 21 cutover CLI command handlers.

soviez_cmd_migration_cutover_plan() {
  soviez_migration_cutover_plan "${SOVIEZ_CLI_MIG_PAIR_ID:-}"
}

soviez_cmd_migration_cutover_plan_show() {
  soviez_migration_cutover_plan_show "${SOVIEZ_CLI_MIG_PLAN_ID:-}"
}

soviez_cmd_migration_cutover_start() {
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  soviez_migration_cutover_start "${SOVIEZ_CLI_MIG_PAIR_ID:-}" "$confirm"
}

soviez_cmd_migration_cutover_status() {
  soviez_migration_cutover_status "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_cutover_retry() {
  soviez_migration_cutover_retry "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_cutover_recover() {
  soviez_migration_cutover_recover "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_cutover_dns_show() {
  soviez_migration_cutover_dns_show "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_cutover_dns_try_again() {
  soviez_migration_cutover_dns_try_again "${SOVIEZ_CLI_OP_ID:-}"
}

soviez_cmd_migration_cutover_rollback() {
  local confirm="${SOVIEZ_CLI_CONFIRM:-0}"
  [[ "${SOVIEZ_CLI_YES:-0}" == "1" ]] && confirm=1
  [[ "$confirm" == "1" ]] || soviez_migration_die MIGRATION_CONFIRMATION_REQUIRED "cutover rollback requires --confirm"
  soviez_migration_cutover_paths_init
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  local st pair_id auth_id fqdn prev_target
  st="$(soviez_migration_cutover_status "$op_id")"
  pair_id="$(soviez_json_get "$st" pair_id)"
  auth_id="$(soviez_json_get "$st" authorization_id)"
  fqdn="$(soviez_json_get "$st" fqdn)"
  prev_target="$(soviez_json_get "$st" previous_dns_target)"
  soviez_migration_rollback_run "$pair_id" "$op_id" "$auth_id" "$fqdn" "$prev_target" "${SOVIEZ_CLI_MIG_DUAL_CONTROL_CONFIRMED:-0}"
}

soviez_cmd_migration_traffic_owner_show() {
  soviez_migration_traffic_owner_get "${SOVIEZ_CLI_MIG_AUTH_ID:-${SOVIEZ_CLI_OP_ID:-}}"
}

soviez_cmd_migration_phase22_readiness() {
  soviez_migration_phase22_readiness "${SOVIEZ_CLI_MIG_AUTH_ID:-}"
}

soviez_cmd_migration_phase22_readiness_show() {
  soviez_migration_phase22_readiness_show "${SOVIEZ_CLI_MIG_REPORT_ID:-}"
}
