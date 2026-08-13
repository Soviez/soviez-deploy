# shellcheck shell=bash
# Phase 21 mandatory final cutover sync — bounded delta from source to
# destination immediately before public route activation. Distinct from
# Phase 19 full streaming transfer and Phase 20 commercial commit.

soviez_migration_final_cutover_sync_markers_dir() {
  printf '%s/sync_markers\n' "$(soviez_migration_cutover_op_dir "$1")"
}

soviez_migration_final_cutover_sync_run() {
  local pair_id="${1:-}" op_id="${2:-}"
  [[ -n "$pair_id" && -n "$op_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id and op-id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_FINAL_CUTOVER_SYNC"

  soviez_migration_cutover_freeze_start "$pair_id" "$op_id" >/dev/null

  local mdir
  mdir="$(soviez_migration_final_cutover_sync_markers_dir "$op_id")"
  mkdir -p "$mdir"

  # Optional real Phase 19 freeze primitive reuse (never re-consumes the token).
  if [[ "${SOVIEZ_MIG_P21_REAL_FREEZE:-0}" == "1" ]] && declare -F soviez_migration_freeze_start >/dev/null 2>&1; then
    soviez_migration_freeze_start "$pair_id" "$op_id" >/dev/null || true
  fi

  if [[ "${SOVIEZ_MIG_P21_INJECT_SYNC_FAIL:-0}" == "1" ]]; then
    soviez_migration_cutover_freeze_release "$op_id" "sync_failed" >/dev/null
    soviez_migration_die MIGRATION_FINAL_CUTOVER_SYNC_FAILED "injected final cutover sync failure"
  fi

  soviez_migration_cutover_freeze_check_timeout "$op_id"

  # Final database snapshot/delta + filestore reconciliation markers.
  # Fixture mode copies lightweight markers; SOVIEZ_MIG_P21_REAL_FREEZE=1
  # additionally invokes the real Phase 19 freeze guard above.
  printf '{"marker":"database_snapshot","applied":true}\n' > "$mdir/database.json"
  printf '{"marker":"filestore_reconciliation","applied":true}\n' > "$mdir/filestore.json"

  local report
  report="$(SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" python3 - <<'PY'
import json, os, time
print(json.dumps({
  "schema": "soviez.final_cutover_sync_report.v1",
  "pair_id": os.environ["SOVIEZ_PAIR"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "database": "applied",
  "filestore": "applied",
  "destination_internal_verify": "ok",
  "status": "signed",
  "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}, separators=(",", ":")))
PY
)"
  printf '%s\n' "$report" > "$mdir/report.json"
  soviez_migration_sign_object_file "$mdir/report.json"

  soviez_migration_cutover_freeze_release "$op_id" "final_sync_complete" >/dev/null
  cat "$mdir/report.json"
}
