# shellcheck shell=bash

soviez_migration_paths_init() {
  if declare -F soviez_paths_init >/dev/null 2>&1; then
    soviez_paths_init
  fi
  if declare -F soviez_ops_paths_init >/dev/null 2>&1; then
    soviez_ops_paths_init 2>/dev/null || true
  fi
  SOVIEZ_MIG_ROOT="${SOVIEZ_MIG_ROOT:-${SOVIEZ_ROOT:-/var/soviez}/migration}"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_ROOT:-}" ]]; then
    SOVIEZ_MIG_ROOT="$SOVIEZ_ROOT/migration"
  fi
  SOVIEZ_MIG_DISCOVERY_DIR="$SOVIEZ_MIG_ROOT/discoveries"
  SOVIEZ_MIG_BOOTSTRAP_DIR="$SOVIEZ_MIG_ROOT/bootstraps"
  SOVIEZ_MIG_PAIR_DIR="$SOVIEZ_MIG_ROOT/pairs"
  SOVIEZ_MIG_READINESS_DIR="$SOVIEZ_MIG_ROOT/readiness"
  SOVIEZ_MIG_CODE_DIR="$SOVIEZ_MIG_ROOT/codes"
  SOVIEZ_MIG_OFFLINE_DIR="$SOVIEZ_MIG_ROOT/offline"
  SOVIEZ_MIG_WORKSPACE_DIR="$SOVIEZ_MIG_ROOT/workspace"
  SOVIEZ_MIG_SECRETS_DIR="$SOVIEZ_MIG_ROOT/secrets"
  SOVIEZ_MIG_TRUST_DIR="$SOVIEZ_MIG_ROOT/trust"
  SOVIEZ_MIG_EVIDENCE_DIR="$SOVIEZ_MIG_ROOT/evidence"
  SOVIEZ_MIG_DOMAIN_PLAN_DIR="$SOVIEZ_MIG_ROOT/domain_plans"
  SOVIEZ_MIG_DNS_CHALLENGE_DIR="$SOVIEZ_MIG_ROOT/dns_challenges"
  SOVIEZ_MIG_LANDING_DIR="$SOVIEZ_MIG_ROOT/landings"
  SOVIEZ_MIG_TLS_DIR="$SOVIEZ_MIG_ROOT/mig_tls"
  SOVIEZ_MIG_ROUTING_PLAN_DIR="$SOVIEZ_MIG_ROOT/routing_plans"
  SOVIEZ_MIG_DNS_REPLAY_DIR="$SOVIEZ_MIG_ROOT/dns_replay"
  SOVIEZ_MIG_DOMAIN_OPS_DIR="$SOVIEZ_MIG_ROOT/domain_ops"
  # Phase 19
  SOVIEZ_MIG_TRANSFER_PLANS_DIR="$SOVIEZ_MIG_ROOT/transfer_plans"
  SOVIEZ_MIG_TRANSFER_MANIFESTS_DIR="$SOVIEZ_MIG_ROOT/transfer_manifests"
  SOVIEZ_MIG_TRANSFER_OPS_DIR="$SOVIEZ_MIG_ROOT/transfer_ops"
  SOVIEZ_MIG_TRANSFER_CHUNKS_DIR="$SOVIEZ_MIG_ROOT/transfer_chunks"
  SOVIEZ_MIG_TRANSFER_CHANNEL_DIR="$SOVIEZ_MIG_ROOT/transfer_channel"
  SOVIEZ_MIG_STAGING_DIR="$SOVIEZ_MIG_ROOT/staging"
  SOVIEZ_MIG_FREEZE_DIR="$SOVIEZ_MIG_ROOT/freeze"
  SOVIEZ_MIG_STAGE_SELECTION_DIR="$SOVIEZ_MIG_ROOT/stage_selection"
  export SOVIEZ_MIG_ROOT SOVIEZ_MIG_DISCOVERY_DIR SOVIEZ_MIG_BOOTSTRAP_DIR SOVIEZ_MIG_PAIR_DIR
  export SOVIEZ_MIG_READINESS_DIR SOVIEZ_MIG_CODE_DIR SOVIEZ_MIG_OFFLINE_DIR
  export SOVIEZ_MIG_WORKSPACE_DIR SOVIEZ_MIG_SECRETS_DIR SOVIEZ_MIG_TRUST_DIR SOVIEZ_MIG_EVIDENCE_DIR
  export SOVIEZ_MIG_DOMAIN_PLAN_DIR SOVIEZ_MIG_DNS_CHALLENGE_DIR SOVIEZ_MIG_LANDING_DIR
  export SOVIEZ_MIG_TLS_DIR SOVIEZ_MIG_ROUTING_PLAN_DIR SOVIEZ_MIG_DNS_REPLAY_DIR SOVIEZ_MIG_DOMAIN_OPS_DIR
  export SOVIEZ_MIG_TRANSFER_PLANS_DIR SOVIEZ_MIG_TRANSFER_MANIFESTS_DIR SOVIEZ_MIG_TRANSFER_OPS_DIR
  export SOVIEZ_MIG_TRANSFER_CHUNKS_DIR SOVIEZ_MIG_TRANSFER_CHANNEL_DIR SOVIEZ_MIG_STAGING_DIR
  export SOVIEZ_MIG_FREEZE_DIR SOVIEZ_MIG_STAGE_SELECTION_DIR
  mkdir -p "$SOVIEZ_MIG_DISCOVERY_DIR" "$SOVIEZ_MIG_BOOTSTRAP_DIR" "$SOVIEZ_MIG_PAIR_DIR" \
    "$SOVIEZ_MIG_READINESS_DIR" "$SOVIEZ_MIG_CODE_DIR" "$SOVIEZ_MIG_OFFLINE_DIR" \
    "$SOVIEZ_MIG_WORKSPACE_DIR" "$SOVIEZ_MIG_SECRETS_DIR" "$SOVIEZ_MIG_TRUST_DIR" "$SOVIEZ_MIG_EVIDENCE_DIR" \
    "$SOVIEZ_MIG_DOMAIN_PLAN_DIR" "$SOVIEZ_MIG_DNS_CHALLENGE_DIR" "$SOVIEZ_MIG_LANDING_DIR" \
    "$SOVIEZ_MIG_TLS_DIR" "$SOVIEZ_MIG_ROUTING_PLAN_DIR" "$SOVIEZ_MIG_DNS_REPLAY_DIR" "$SOVIEZ_MIG_DOMAIN_OPS_DIR" \
    "$SOVIEZ_MIG_TRANSFER_PLANS_DIR" "$SOVIEZ_MIG_TRANSFER_MANIFESTS_DIR" "$SOVIEZ_MIG_TRANSFER_OPS_DIR" \
    "$SOVIEZ_MIG_TRANSFER_CHUNKS_DIR" "$SOVIEZ_MIG_TRANSFER_CHANNEL_DIR" "$SOVIEZ_MIG_STAGING_DIR" \
    "$SOVIEZ_MIG_FREEZE_DIR" "$SOVIEZ_MIG_STAGE_SELECTION_DIR"
  chmod 700 "$SOVIEZ_MIG_SECRETS_DIR" "$SOVIEZ_MIG_TRUST_DIR" 2>/dev/null || true
}

soviez_migration_new_id() {
  local prefix="${1:-mig}"
  printf '%s-%s\n' "$prefix" "$(openssl rand -hex 8)"
}

soviez_migration_discovery_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_DISCOVERY_DIR" "$1"; }
soviez_migration_bootstrap_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_BOOTSTRAP_DIR" "$1"; }
soviez_migration_pair_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_PAIR_DIR" "$1"; }
soviez_migration_readiness_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_READINESS_DIR" "$1"; }
soviez_migration_domain_plan_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_DOMAIN_PLAN_DIR" "$1"; }
soviez_migration_dns_challenge_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_DNS_CHALLENGE_DIR" "$1"; }
soviez_migration_landing_site_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_LANDING_DIR" "$1"; }
soviez_migration_tls_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TLS_DIR" "$1"; }
soviez_migration_routing_plan_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_ROUTING_PLAN_DIR" "$1"; }
soviez_migration_domain_ops_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_DOMAIN_OPS_DIR" "$1"; }
soviez_migration_transfer_plan_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TRANSFER_PLANS_DIR" "$1"; }
soviez_migration_transfer_manifest_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TRANSFER_MANIFESTS_DIR" "$1"; }
soviez_migration_transfer_op_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TRANSFER_OPS_DIR" "$1"; }
soviez_migration_transfer_chunks_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TRANSFER_CHUNKS_DIR" "$1"; }
soviez_migration_transfer_channel_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_TRANSFER_CHANNEL_DIR" "$1"; }
soviez_migration_staging_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_STAGING_DIR" "$1"; }
soviez_migration_freeze_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_FREEZE_DIR" "$1"; }
soviez_migration_stage_selection_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_STAGE_SELECTION_DIR" "$1"; }
