# shellcheck shell=bash
# Stage paths and inventory layout (Phase 11).

soviez_stage_paths_init() {
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Always derive from current SOVIEZ_ROOT so leftover exported path vars
    # from prior shells cannot cross-contaminate disposable fixtures.
    SOVIEZ_STAGES_DIR="$SOVIEZ_ROOT/stages"
    SOVIEZ_STAGE_OPS_DIR="$SOVIEZ_ROOT/ops/stage"
    SOVIEZ_STAGE_HELPER_BIN="${SOVIEZ_STAGE_HELPER_BIN:-}"
    SOVIEZ_STAGE_TOOLING_CACHE="$SOVIEZ_ROOT/cache/stage-tooling"
    SOVIEZ_STAGE_LEDGER="$SOVIEZ_ROOT/stages/consumption.jsonl"
  else
    SOVIEZ_STAGES_DIR="${SOVIEZ_STAGES_DIR:-/var/soviez/stages}"
    SOVIEZ_STAGE_OPS_DIR="${SOVIEZ_STAGE_OPS_DIR:-/var/soviez/ops/stage}"
    SOVIEZ_STAGE_HELPER_BIN="${SOVIEZ_STAGE_HELPER_BIN:-/usr/local/lib/soviez/stage-operation-helper/soviez-stage-helper}"
    SOVIEZ_STAGE_TOOLING_CACHE="${SOVIEZ_STAGE_TOOLING_CACHE:-/var/soviez/cache/stage-tooling}"
    SOVIEZ_STAGE_LEDGER="${SOVIEZ_STAGE_LEDGER:-/var/soviez/stages/consumption.jsonl}"
  fi
  export SOVIEZ_STAGES_DIR SOVIEZ_STAGE_OPS_DIR SOVIEZ_STAGE_HELPER_BIN
  export SOVIEZ_STAGE_TOOLING_CACHE SOVIEZ_STAGE_LEDGER
  mkdir -p "$SOVIEZ_STAGES_DIR" "$SOVIEZ_STAGE_OPS_DIR" "$SOVIEZ_STAGE_TOOLING_CACHE"
  chmod 700 "$SOVIEZ_STAGES_DIR" "$SOVIEZ_STAGE_OPS_DIR" 2>/dev/null || true
}

soviez_stage_inventory_index() {
  printf '%s/index.json\n' "$SOVIEZ_STAGES_DIR"
}

soviez_stage_dir() {
  local stage_id="$1"
  printf '%s/%s\n' "$SOVIEZ_STAGES_DIR" "$stage_id"
}

soviez_stage_identity_file() {
  printf '%s/identity.json\n' "$(soviez_stage_dir "$1")"
}

soviez_stage_origin_cert_file() {
  printf '%s/origin-certificate.json\n' "$(soviez_stage_dir "$1")"
}

soviez_stage_filestore_path() {
  printf '%s/filestore\n' "$(soviez_stage_dir "$1")"
}

soviez_stage_config_path() {
  printf '%s/config\n' "$(soviez_stage_dir "$1")"
}

soviez_stage_secrets_path() {
  printf '%s/secrets\n' "$(soviez_stage_dir "$1")"
}

soviez_stage_snapshot_dir() {
  local op_id="$1"
  printf '%s/%s/snapshots\n' "$SOVIEZ_STAGE_OPS_DIR" "$op_id"
}

soviez_stage_op_dir() {
  printf '%s/%s\n' "$SOVIEZ_STAGE_OPS_DIR" "$1"
}

soviez_stage_op_state_file() {
  printf '%s/state.json\n' "$(soviez_stage_op_dir "$1")"
}
