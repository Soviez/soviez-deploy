# shellcheck shell=bash
# Phase 19 transfer codes — canonical list lives in migration/common/codes.sh

soviez_migration_transfer_token_flags_json() {
  printf '{"migration_token_reserved":false,"migration_token_consumed":false,"destination_production_activated":false,"traffic_cutover_started":false,"source_license_active":true,"source_runtime_active":true}\n'
}

soviez_migration_transfer_phase20_banner() {
  local pair_state="${1:-VALID}"
  local routing_state="${2:-VALID}"
  local backup_state="${3:-VERIFIED}"
  local manifest_state="${4:-SIGNED}"
  local channel_state="${5:-ESTABLISHED}"
  local db_state="${6:-COMPLETE}"
  local fs_state="${7:-COMPLETE}"
  local addon_state="${8:-COMPLETE}"
  local stages_state="${9:-COMPLETE}"
  local staging_state="${10:-VERIFIED}"
  local ready="${11:-PASS}"
  cat <<EOF
MIGRATION PAIR — ${pair_state}
ROUTING READINESS — ${routing_state}
PRE-MIGRATION BACKUP — ${backup_state}
TRANSFER MANIFEST — ${manifest_state}
SECURE CHANNEL — ${channel_state}
DATABASE TRANSFER — ${db_state}
FILESTORE TRANSFER — ${fs_state}
ADDONS / CONFIG TRANSFER — ${addon_state}
SELECTED STAGES — ${stages_state}
DESTINATION STAGING — ${staging_state}
SOURCE PRODUCTION — ACTIVE
SOURCE WRITE FREEZE — RELEASED
MIGRATION TOKEN — NOT RESERVED / NOT CONSUMED
DESTINATION PRODUCTION — NOT ACTIVATED
TRAFFIC CUTOVER — NOT STARTED
READY FOR PHASE 20 — ${ready}
EOF
}
