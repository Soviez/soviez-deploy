# shellcheck shell=bash
# Phase 22 stabilization path helpers.

soviez_migration_p22_paths_init() {
  soviez_migration_cutover_paths_init
  SOVIEZ_MIG_STABILIZATION_DIR="$SOVIEZ_MIG_ROOT/stabilization"
  SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR="$SOVIEZ_MIG_ROOT/rollback_closure"
  SOVIEZ_MIG_SOURCE_ARCHIVE_DIR="$SOVIEZ_MIG_ROOT/source_archive"
  SOVIEZ_MIG_SOURCE_FINALIZATION_DIR="$SOVIEZ_MIG_ROOT/source_finalization"
  SOVIEZ_MIG_RETIREMENT_DIR="$SOVIEZ_MIG_ROOT/retirement"
  SOVIEZ_MIG_PHASE23_READINESS_DIR="$SOVIEZ_MIG_ROOT/phase23_readiness"
  SOVIEZ_MIG_P22_SUSPEND_DIR="$SOVIEZ_MIG_ROOT/runtime_suspend"
  export SOVIEZ_MIG_STABILIZATION_DIR SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR \
    SOVIEZ_MIG_SOURCE_ARCHIVE_DIR SOVIEZ_MIG_SOURCE_FINALIZATION_DIR \
    SOVIEZ_MIG_RETIREMENT_DIR SOVIEZ_MIG_PHASE23_READINESS_DIR SOVIEZ_MIG_P22_SUSPEND_DIR
  mkdir -p "$SOVIEZ_MIG_STABILIZATION_DIR" "$SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR" \
    "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR" "$SOVIEZ_MIG_SOURCE_FINALIZATION_DIR" \
    "$SOVIEZ_MIG_RETIREMENT_DIR" "$SOVIEZ_MIG_PHASE23_READINESS_DIR" \
    "$SOVIEZ_MIG_P22_SUSPEND_DIR"
}

soviez_migration_p22_stab_dir() {
  [[ -n "${SOVIEZ_MIG_STABILIZATION_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_STABILIZATION_DIR" "$1"
}
soviez_migration_p22_closure_dir() {
  [[ -n "${SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_ROLLBACK_CLOSURE_DIR" "$1"
}
soviez_migration_p22_archive_dir() {
  [[ -n "${SOVIEZ_MIG_SOURCE_ARCHIVE_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR" "$1"
}
soviez_migration_p22_finalization_dir() {
  [[ -n "${SOVIEZ_MIG_SOURCE_FINALIZATION_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_SOURCE_FINALIZATION_DIR" "$1"
}
soviez_migration_p22_retirement_dir() {
  [[ -n "${SOVIEZ_MIG_RETIREMENT_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_RETIREMENT_DIR" "$1"
}
soviez_migration_p22_phase23_dir() {
  [[ -n "${SOVIEZ_MIG_PHASE23_READINESS_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s\n' "$SOVIEZ_MIG_PHASE23_READINESS_DIR" "$1"
}
soviez_migration_p22_suspend_state_path() {
  [[ -n "${SOVIEZ_MIG_P22_SUSPEND_DIR:-}" ]] || soviez_migration_p22_paths_init
  printf '%s/%s/state.json\n' "$SOVIEZ_MIG_P22_SUSPEND_DIR" "$1"
}
