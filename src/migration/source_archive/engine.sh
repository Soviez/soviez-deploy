# shellcheck shell=bash

soviez_migration_source_archive_plan() {
  local source_id="${1:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  soviez_migration_p22_paths_init
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_ARCHIVE_PLAN"
  local st auth_id cutover_id op_id
  cutover_id="${SOVIEZ_MIG_P22_CUTOVER_ID:-$source_id}"
  st="$(soviez_migration_p22_archive_resolve_source "$source_id")"
  auth_id="$(soviez_json_get "$st" authorization_id)"
  op_id="$(soviez_migration_new_id p22a)"
  mkdir -p "$(soviez_migration_p22_archive_op_dir "$op_id")"
  SOVIEZ_OUT="$(soviez_migration_p22_archive_plan_path "$op_id")" \
  SOVIEZ_OP="$op_id" SOVIEZ_SID="$source_id" SOVIEZ_CID="$cutover_id" SOVIEZ_AID="$auth_id" \
  SOVIEZ_ROOT="${SOVIEZ_MIG_P22_SOURCE_ROOT:-}" SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_archive_plan.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "source_id": os.environ["SOVIEZ_SID"],
  "cutover_id": os.environ["SOVIEZ_CID"],
  "authorization_id": os.environ["SOVIEZ_AID"],
  "source_root": os.environ.get("SOVIEZ_ROOT",""),
  "purge_authorized": False,
  "deletion_authorized": False,
  "created_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_p22_archive_state_write "$op_id" "planned" "$source_id" "$cutover_id" "$auth_id" >/dev/null
  cat "$(soviez_migration_p22_archive_plan_path "$op_id")"
}

soviez_migration_source_archive_start() {
  local source_id="${1:-}" reuse_op="${2:-}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  # Soften Phase 21 archive forbid for canonical Phase 22.
  export SOVIEZ_MIG_SOURCE_ARCHIVE=1
  soviez_migration_p22_paths_init
  soviez_migration_assert_phase22_allowed "$SOVIEZ_MIG_OP_SOURCE_ARCHIVE"
  if declare -F soviez_migration_p22_assert_cert_gates >/dev/null 2>&1; then
    soviez_migration_p22_assert_cert_gates
  fi

  local st auth_id cutover_id op_id planf
  cutover_id="${SOVIEZ_MIG_P22_CUTOVER_ID:-$source_id}"
  st="$(soviez_migration_p22_archive_resolve_source "$source_id")"
  auth_id="$(soviez_json_get "$st" authorization_id)"

  if [[ -n "$reuse_op" ]]; then
    op_id="$reuse_op"
  else
    # Prefer existing plan for this source if present via env.
    op_id="${SOVIEZ_MIG_P22_ARCHIVE_OP_ID:-}"
    if [[ -z "$op_id" ]]; then
      local plan
      plan="$(soviez_migration_source_archive_plan "$source_id")"
      op_id="$(soviez_json_get "$plan" operation_id)"
    fi
  fi

  planf="$(soviez_migration_p22_archive_plan_path "$op_id")"
  [[ -f "$planf" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_PLAN_REQUIRED "archive plan required"

  # Holds
  if [[ "${SOVIEZ_MIG_P22_LEGAL_HOLD:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_LEGAL_HOLD_ACTIVE "legal hold active"
  fi
  if [[ "${SOVIEZ_MIG_P22_RETENTION_HOLD:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_RETENTION_HOLD_ACTIVE "retention hold active"
  fi

  soviez_migration_p22_archive_state_write "$op_id" "creating" "$source_id" "$cutover_id" "$auth_id" >/dev/null

  local src_root
  src_root="${SOVIEZ_MIG_P22_SOURCE_ROOT:-}"
  [[ -n "$src_root" ]] || soviez_migration_die MIGRATION_SOURCE_ARCHIVE_CREATE_FAILED "SOVIEZ_MIG_P22_SOURCE_ROOT required"

  soviez_migration_p22_archive_inventory "$op_id" "$src_root" >/dev/null
  soviez_migration_p22_archive_database "$op_id" >/dev/null
  soviez_migration_p22_archive_filestore "$op_id" "${SOVIEZ_MIG_P22_SOURCE_FILESTORE:-$src_root/filestore}" >/dev/null
  soviez_migration_p22_archive_addons "$op_id" >/dev/null
  soviez_migration_p22_archive_config "$op_id" >/dev/null
  soviez_migration_p22_archive_secret_inventory "$op_id" >/dev/null
  soviez_migration_p22_archive_certificates "$op_id" >/dev/null
  soviez_migration_p22_archive_dns "$op_id" "$cutover_id" >/dev/null
  soviez_migration_p22_archive_stages "$op_id" >/dev/null
  soviez_migration_p22_archive_infrastructure "$op_id" >/dev/null
  soviez_migration_p22_archive_encrypt "$op_id" >/dev/null
  # Optional remote store (S3/SFTP) — interrupt/lost-ack recoverable; never deletes source.
  if declare -F soviez_migration_p22_archive_store_remote >/dev/null 2>&1; then
    soviez_migration_p22_archive_store_remote "$op_id" >/dev/null
  fi
  soviez_migration_p22_archive_write_manifest "$op_id" "$cutover_id" "$source_id" >/dev/null
  soviez_migration_p22_archive_sign_manifest "$op_id" >/dev/null
  soviez_migration_p22_archive_verify "$op_id" >/dev/null
  soviez_migration_p22_archive_restore_test "$op_id" >/dev/null
  soviez_migration_p22_archive_full_erp_restore_test "$op_id" >/dev/null

  local report
  report="$(soviez_migration_p22_archive_op_dir "$op_id")/report.json"
  SOVIEZ_OUT="$report" SOVIEZ_OP="$op_id" SOVIEZ_SID="$source_id" SOVIEZ_CID="$cutover_id" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_archive.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "source_id": os.environ["SOVIEZ_SID"],
  "cutover_id": os.environ["SOVIEZ_CID"],
  "status": "verified",
  "purge_authorized": False,
  "deletion_performed": False,
  "created_at": os.environ["SOVIEZ_NOW"],
  "signer": "soviez-p22",
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$report"
  soviez_migration_p22_archive_state_write "$op_id" "verified" "$source_id" "$cutover_id" "$auth_id" '{"status":"verified"}' >/dev/null
  # Index
  mkdir -p "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR/by_source"
  printf '%s\n' "$op_id" > "$SOVIEZ_MIG_SOURCE_ARCHIVE_DIR/by_source/${source_id}.id"
  cat "$report"
}

# Full Phase 22 happy-path orchestrator for fixtures/tests.
# Requires SOVIEZ_MIG_P22_FIXTURE=1 (+ cert clock flags for short stabilization).
soviez_migration_phase22_run() {
  local cutover_id="${1:-}" source_id="${2:-}"
  [[ -n "$cutover_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "cutover-id required"
  source_id="${source_id:-$cutover_id}"
  export SOVIEZ_MIG_P22_CANONICAL=1
  export SOVIEZ_MIG_P22_CUTOVER_ID="$cutover_id"
  export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${cutover_id}"
  soviez_migration_p22_paths_init

  soviez_migration_stabilization_status "$cutover_id" >/dev/null
  # Ensure window appears expired for closure.
  export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
  soviez_migration_rollback_window_close "$cutover_id" >/dev/null
  local archive
  archive="$(soviez_migration_source_archive_start "$source_id")"
  local op_id
  op_id="$(soviez_json_get "$archive" operation_id)"
  soviez_migration_source_license_finalize "$op_id" >/dev/null
  soviez_migration_source_runtime_suspend "$op_id" >/dev/null
  local retirement p23
  retirement="$(soviez_migration_source_retirement_status "$source_id")"
  p23="$(soviez_migration_phase23_readiness "$op_id")"
  SOVIEZ_AID="$op_id" SOVIEZ_CID="$cutover_id" SOVIEZ_SID="$source_id" \
  SOVIEZ_RET="$retirement" SOVIEZ_P23="$p23" python3 - <<'PY'
import json, os
print(json.dumps({
  "status": "phase22_complete",
  "cutover_id": os.environ["SOVIEZ_CID"],
  "source_id": os.environ["SOVIEZ_SID"],
  "archive_operation_id": os.environ["SOVIEZ_AID"],
  "retirement": json.loads(os.environ["SOVIEZ_RET"]),
  "phase23_readiness": json.loads(os.environ["SOVIEZ_P23"]),
  "purges_source": False,
}, separators=(",", ":")))
PY
}
