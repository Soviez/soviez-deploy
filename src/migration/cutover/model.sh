# shellcheck shell=bash
# Phase 21 cutover path helpers.

soviez_migration_cutover_paths_init() {
  soviez_migration_paths_init
  soviez_migration_p20_paths_init
  SOVIEZ_MIG_CUTOVER_DIR="$SOVIEZ_MIG_ROOT/cutover"
  SOVIEZ_MIG_CUTOVER_PLAN_DIR="$SOVIEZ_MIG_CUTOVER_DIR/plans"
  SOVIEZ_MIG_CUTOVER_OPS_DIR="$SOVIEZ_MIG_CUTOVER_DIR/ops"
  SOVIEZ_MIG_TRAFFIC_OWNER_DIR="$SOVIEZ_MIG_ROOT/traffic_owner"
  export SOVIEZ_MIG_CUTOVER_DIR SOVIEZ_MIG_CUTOVER_PLAN_DIR SOVIEZ_MIG_CUTOVER_OPS_DIR SOVIEZ_MIG_TRAFFIC_OWNER_DIR
  mkdir -p "$SOVIEZ_MIG_CUTOVER_PLAN_DIR" "$SOVIEZ_MIG_CUTOVER_OPS_DIR" "$SOVIEZ_MIG_TRAFFIC_OWNER_DIR" \
    "$SOVIEZ_MIG_ROOT/source_transition" "$SOVIEZ_MIG_ROOT/phase22_readiness"
}

soviez_migration_cutover_plan_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_CUTOVER_PLAN_DIR" "$1"; }
soviez_migration_cutover_op_dir() { printf '%s/%s\n' "$SOVIEZ_MIG_CUTOVER_OPS_DIR" "$1"; }
soviez_migration_traffic_owner_path() { printf '%s/%s.json\n' "$SOVIEZ_MIG_TRAFFIC_OWNER_DIR" "$1"; }
soviez_migration_cutover_state_path() { printf '%s/state.json\n' "$(soviez_migration_cutover_op_dir "$1")"; }
soviez_migration_cutover_rollback_window_path() { printf '%s/rollback_window.json\n' "$(soviez_migration_cutover_op_dir "$1")"; }
