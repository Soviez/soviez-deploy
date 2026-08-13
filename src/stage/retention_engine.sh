# shellcheck shell=bash
# Phase 13 — final backup, Safe Shield deletion, resume and scheduling.

soviez_retention_mark_step() {
  local stage_id="$1" step="$2" steps
  steps="$(soviez_json_get "$(soviez_retention_read "$stage_id")" completed_deletion_steps)"
  soviez_retention_patch "$stage_id" "$(SOVIEZ_STEPS="$steps" SOVIEZ_STEP="$step" python3 - <<'PY'
import json, os
steps=json.loads(os.environ["SOVIEZ_STEPS"] or "[]")
if os.environ["SOVIEZ_STEP"] not in steps:
    steps.append(os.environ["SOVIEZ_STEP"])
print(json.dumps({"completed_deletion_steps": steps}, separators=(",", ":")))
PY
)"
}

soviez_retention_step_done() {
  SOVIEZ_STEPS="$(soviez_json_get "$(soviez_retention_read "$1")" completed_deletion_steps)" SOVIEZ_STEP="$2" python3 - <<'PY'
import json, os, sys
sys.exit(0 if os.environ["SOVIEZ_STEP"] in json.loads(os.environ["SOVIEZ_STEPS"] or "[]") else 1)
PY
}

soviez_retention_fail() {
  local stage_id="$1" code="$2" message="$3" status="${4:-needs_action}"
  soviez_retention_lock_release "$stage_id" 2>/dev/null || true
  unset SOVIEZ_RETENTION_HOLDING_LOCK
  # Write terminal failure state without banner refresh (refresh must not demote).
  soviez_retention_patch "$stage_id" "$(SOVIEZ_CODE="$code" SOVIEZ_STATUS="$status" python3 - <<'PY'
import json, os
print(json.dumps({
  "retention_status": os.environ["SOVIEZ_STATUS"],
  "last_failure_code": os.environ["SOVIEZ_CODE"],
}, separators=(",", ":")))
PY
)" 2>/dev/null || true
  # Banner best-effort; re-apply status afterward
  ( soviez_retention_render_banner "$stage_id" >/dev/null ) 2>/dev/null || true
  soviez_retention_patch "$stage_id" "$(SOVIEZ_CODE="$code" SOVIEZ_STATUS="$status" python3 - <<'PY'
import json, os
print(json.dumps({
  "retention_status": os.environ["SOVIEZ_STATUS"],
  "last_failure_code": os.environ["SOVIEZ_CODE"],
}, separators=(",", ":")))
PY
)" 2>/dev/null || true
  soviez_retention_die "$code" "$message"
}

soviez_retention_final_backup() {
  local stage_id="$1" before archive sum dest_root backup_dir
  [[ "${SOVIEZ_RETENTION_INJECT_BACKUP_FAIL:-0}" != "1" ]] || return 1
  dest_root="${SOVIEZ_ROOT:-/var/soviez}/backups/retention"
  mkdir -p "$dest_root"
  case "$dest_root" in
    "$(soviez_stage_dir "$stage_id")"*) return 1 ;;
  esac
  before="$(mktemp "${TMPDIR:-/tmp}/soviez-retention-backup.XXXXXX")"
  soviez_stage_cmd_backup "$stage_id" > "$before" 2>&1 || { rm -f "$before"; return 1; }
  archive="$(awk -F': ' '/^Backup written: /{archive=$2} END{print archive}' "$before")"
  rm -f "$before"
  [[ -n "$archive" && -f "$archive" ]] || return 1
  case "$archive" in
    "$(soviez_stage_dir "$stage_id")"*) return 1 ;;
  esac
  sum="$(soviez_sha256_file "$archive" 2>/dev/null || true)"
  [[ -n "$sum" && -f "${archive}.sha256" && "$sum" == "$(tr -d '[:space:]' < "${archive}.sha256")" ]] || return 1
  [[ "${SOVIEZ_RETENTION_INJECT_BACKUP_CHECKSUM_FAIL:-0}" != "1" && "${SOVIEZ_RETENTION_INJECT_CHECKSUM_FAIL:-0}" != "1" ]] || return 1
  backup_dir="$dest_root/${stage_id}/$(basename "$archive" .tar)"
  mkdir -p "$backup_dir"
  cp -a "$archive" "${archive}.sha256" "$backup_dir/" 2>/dev/null || true
  printf '%s' "$(soviez_retention_read "$stage_id")" > "$backup_dir/retention.json"
  soviez_retention_patch "$stage_id" "$(SOVIEZ_PATH="$backup_dir" SOVIEZ_SUM="$sum" python3 - <<'PY'
import json, os
print(json.dumps({
  "final_backup_status": "ok",
  "final_backup_path": os.environ["SOVIEZ_PATH"],
  "final_backup_checksum": os.environ["SOVIEZ_SUM"],
}, separators=(",", ":")))
PY
)"
  return 0
}

soviez_retention_remove_inventory() {
  local stage_id="$1" index new_index
  index="$(soviez_stage_inventory_index)"
  new_index="$(SOVIEZ_IDX="$(soviez_stage_inventory_load_index)" SOVIEZ_SID="$stage_id" python3 - <<'PY'
import json, os
d=json.loads(os.environ["SOVIEZ_IDX"])
d["stages"]=[s for s in d.get("stages",[]) if s.get("stage_id") != os.environ["SOVIEZ_SID"]]
print(json.dumps(d, separators=(",", ":")))
PY
)"
  soviez_stage_inventory_atomic_write "$index" "$new_index"
}

soviez_retention_write_tombstone() {
  local stage_id="$1" reason="$2" rec ident tombstone
  rec="$(soviez_retention_read "$stage_id" 2>/dev/null || echo '{}')"
  ident="$(soviez_stage_inventory_find "$stage_id" 2>/dev/null || echo '{}')"
  tombstone="$(soviez_retention_tombstone_file "$stage_id")"
  mkdir -p "$(dirname "$tombstone")"
  chmod 700 "$(dirname "$tombstone")" 2>/dev/null || true
  REC="$rec" IDENT="$ident" REASON="$reason" NOW="$(soviez_retention_now_utc)" SID="$stage_id" \
    VER="$SOVIEZ_RETENTION_POLICY_VERSION" python3 - <<'PY' > "$tombstone"
import json, os
rec=json.loads(os.environ.get("REC") or "{}")
ident=json.loads(os.environ.get("IDENT") or "{}")
lic=str(ident.get("license_id") or "")
if len(lic) > 12:
    lic = lic[:8] + "…"
print(json.dumps({
  "stage_id": os.environ["SID"],
  "parent_production_tenant_id": ident.get("parent_production_tenant_id"),
  "license_id_abbrev": lic,
  "domain": ident.get("stage_domain"),
  "original_creation_timestamp": rec.get("created_at"),
  "final_deadline": rec.get("current_retention_deadline"),
  "extension_count": rec.get("extension_count"),
  "requested_extension_days": rec.get("requested_extension_days"),
  "deletion_completed_timestamp": os.environ["NOW"],
  "deletion_reason": os.environ["REASON"],
  "operation_id": rec.get("retention_operation_id"),
  "backup_path": rec.get("final_backup_path"),
  "backup_checksum": rec.get("final_backup_checksum"),
  "deleted_resource_manifest": rec.get("completed_deletion_steps") or [],
  "safe_shield_status": rec.get("safe_shield_status"),
  "retention_policy_version": os.environ["VER"],
}, indent=2))
PY
}

soviez_retention_run_deletion() {
  local stage_id="$1" force="${2:-0}" rec days identity db fs cfg secrets container network op_id
  soviez_stage_paths_init
  soviez_retention_ensure "$stage_id"
  soviez_retention_lock_acquire "$stage_id"
  export SOVIEZ_RETENTION_HOLDING_LOCK=1
  trap 'soviez_retention_lock_release "'"$stage_id"'"; unset SOVIEZ_RETENTION_HOLDING_LOCK' EXIT

  soviez_retention_refresh_derived "$stage_id"
  rec="$(soviez_retention_read "$stage_id")"
  days="$(soviez_json_get "$rec" days_remaining)"
  [[ "$force" == "1" || "$days" -le 0 ]] || soviez_retention_fail "$stage_id" RETENTION_NOT_DUE "Retention deadline has not elapsed"

  local cur_e max_e created expected_max
  created="$(soviez_json_get "$rec" created_at)"
  expected_max="$(soviez_retention_add_calendar_days_utc "$created" "$SOVIEZ_RETENTION_MAXIMUM_DAYS")"
  if [[ "$(soviez_json_get "$rec" maximum_retention_deadline)" != "$expected_max" ]]; then
    soviez_retention_fail "$stage_id" RETENTION_METADATA_CORRUPT "maximum_retention_deadline tampered"
  fi
  cur_e="$(soviez_retention_parse_utc_epoch "$(soviez_json_get "$rec" current_retention_deadline)")"
  max_e="$(soviez_retention_parse_utc_epoch "$(soviez_json_get "$rec" maximum_retention_deadline)")"
  (( cur_e <= max_e )) || soviez_retention_fail "$stage_id" RETENTION_MAXIMUM_EXCEEDED "Retention deadline exceeds maximum"

  op_id="$(soviez_json_get "$rec" retention_operation_id)"
  if [[ -z "$op_id" || "$op_id" == "null" ]]; then
    op_id="ret-del-${stage_id}-$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  soviez_retention_patch "$stage_id" "$(SOVIEZ_OP="$op_id" SOVIEZ_NOW="$(soviez_retention_now_utc)" python3 - <<'PY'
import json, os
print(json.dumps({
  "retention_operation_id": os.environ["SOVIEZ_OP"],
  "deletion_started_at": os.environ["SOVIEZ_NOW"],
  "retention_status": "final_backup_running",
  "state": "final_backup",
}, separators=(",", ":")))
PY
)"
  # Continuous sync replaces migrate-on-write; sync happens via retention_patch.
  if declare -F soviez_ops_sync_transition >/dev/null 2>&1; then
    soviez_ops_sync_transition "$op_id" retention_delete "$stage_id" "final_backup_running" "created" "{}" "$(soviez_retention_file "$stage_id")" \
      || soviez_ops_sync_mark_pending "$op_id" OPERATION_CANONICAL_SYNC_PENDING
  fi

  if ! soviez_retention_final_backup "$stage_id"; then
    soviez_retention_fail "$stage_id" FINAL_RETENTION_BACKUP_FAILED "Final backup failed" needs_action
  fi
  soviez_retention_mark_step "$stage_id" final_backup

  soviez_retention_patch "$stage_id" '{"retention_status":"safe_shield_validating"}'
  if ! soviez_retention_safe_shield_validate "$stage_id" >/dev/null; then
    soviez_retention_fail "$stage_id" SAFE_SHIELD_VALIDATION_FAILED "Safe Shield rejected deletion" needs_action
  fi
  soviez_retention_patch "$stage_id" '{"safe_shield_status":"ok","retention_status":"deletion_running","last_failure_code":null}'

  identity="$(soviez_stage_inventory_find "$stage_id")"
  db="$(soviez_json_get "$identity" stage_db_name)"
  fs="$(soviez_json_get "$identity" stage_filestore_path)"
  cfg="$(soviez_json_get "$identity" stage_config_path)"
  secrets="$(soviez_json_get "$identity" stage_secrets_path)"
  container="$(soviez_json_get "$identity" stage_container)"
  network="$(soviez_json_get "$identity" stage_network)"

  if ! soviez_retention_step_done "$stage_id" stop_container; then
    [[ "${SOVIEZ_RETENTION_INJECT_STOP_FAIL:-0}" != "1" ]] || soviez_retention_fail "$stage_id" RETENTION_PARTIAL_DELETION "Stop failed" recovery_required
    soviez_stage_runtime_stop "$stage_id" || true
    if command -v docker >/dev/null 2>&1; then
      docker stop "$container" 2>/dev/null || true
    fi
    soviez_retention_mark_step "$stage_id" stop_container
  fi

  if ! soviez_retention_step_done "$stage_id" verify_production_healthy; then
    [[ -f "${SOVIEZ_PRODUCTION_HEALTH_FILE:-${SOVIEZ_ROOT:-/var/soviez}/production.ok}" ]] \
      || soviez_retention_fail "$stage_id" SAFE_SHIELD_VALIDATION_FAILED "Production health file missing" needs_action
    soviez_retention_mark_step "$stage_id" verify_production_healthy
  fi

  if ! soviez_retention_step_done "$stage_id" remove_nginx; then
    [[ "${SOVIEZ_RETENTION_INJECT_NGINX_FAIL:-0}" != "1" ]] || soviez_retention_fail "$stage_id" RETENTION_PARTIAL_DELETION "Nginx removal failed" recovery_required
    rm -rf "$cfg/nginx" 2>/dev/null || true
    rm -f "$cfg/nginx.owned" "$cfg/nginx.conf" 2>/dev/null || true
    soviez_retention_mark_step "$stage_id" remove_nginx
  fi

  if ! soviez_retention_step_done "$stage_id" remove_container; then
    if command -v docker >/dev/null 2>&1; then
      docker rm -f "$container" 2>/dev/null || true
    fi
    if declare -F soviez_stage_runtime_remove_owned >/dev/null; then
      soviez_stage_runtime_remove_owned "$stage_id" 2>/dev/null || true
    fi
    soviez_retention_mark_step "$stage_id" remove_container
  fi

  if ! soviez_retention_step_done "$stage_id" remove_database; then
    if [[ "${SOVIEZ_RETENTION_INJECT_DB_FAIL:-0}" == "1" ]]; then
      soviez_retention_fail "$stage_id" RETENTION_PARTIAL_DELETION "Database removal failed" recovery_required
    fi
    [[ "$db" != *"*"* ]] || soviez_retention_fail "$stage_id" STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS "Wildcard database target" needs_action
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      rm -rf "${SOVIEZ_ROOT}/stage-dbs/$db"
    elif declare -F soviez_stage_use_live_pg >/dev/null && soviez_stage_use_live_pg; then
      # Exact Stage DB only — never wildcard or multi-DB cleanup.
      local db_drop_sql
      db_drop_sql="$(printf 'DROP %s "%s";' DATABASE "$db")"
      soviez_stage_pg_psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db}' AND pid <> pg_backend_pid();" >/dev/null || true
      soviez_stage_pg_psql -d postgres -c "$db_drop_sql" >/dev/null || soviez_retention_fail "$stage_id" RETENTION_PARTIAL_DELETION "Database drop failed" recovery_required
    fi
    soviez_retention_mark_step "$stage_id" remove_database
  fi

  if ! soviez_retention_step_done "$stage_id" remove_filestore; then
    if [[ "${SOVIEZ_RETENTION_INJECT_FS_FAIL:-0}" == "1" ]]; then
      soviez_retention_fail "$stage_id" RETENTION_PARTIAL_DELETION "Filestore removal failed" recovery_required
    fi
    case "$fs" in
      "$(soviez_stage_dir "$stage_id")"/*) rm -rf "$fs" ;;
      *) soviez_retention_fail "$stage_id" STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS "Filestore outside Stage root" needs_action ;;
    esac
    soviez_retention_mark_step "$stage_id" remove_filestore
  fi

  if ! soviez_retention_step_done "$stage_id" remove_volumes; then
    rm -rf "$(soviez_stage_dir "$stage_id")/volumes" 2>/dev/null || true
    soviez_retention_mark_step "$stage_id" remove_volumes
  fi

  if ! soviez_retention_step_done "$stage_id" remove_network; then
    if command -v docker >/dev/null 2>&1; then
      docker network rm "$network" 2>/dev/null || true
    fi
    soviez_retention_mark_step "$stage_id" remove_network
  fi

  if ! soviez_retention_step_done "$stage_id" remove_config_secrets; then
    rm -rf "$cfg" "$secrets" 2>/dev/null || true
    soviez_retention_mark_step "$stage_id" remove_config_secrets
  fi

  if ! soviez_retention_step_done "$stage_id" remove_certificate_if_unshared; then
    local shared
    shared="$(soviez_json_get "$identity" certificate_shared_wildcard 2>/dev/null || true)"
    if [[ "$shared" != "true" ]]; then
      rm -rf "$(soviez_stage_dir "$stage_id")/certs" 2>/dev/null || true
    fi
    soviez_retention_mark_step "$stage_id" remove_certificate_if_unshared
  fi

  soviez_retention_write_tombstone "$stage_id" "retention_deadline"

  if ! soviez_retention_step_done "$stage_id" remove_inventory; then
    soviez_retention_remove_inventory "$stage_id"
    soviez_retention_mark_step "$stage_id" remove_inventory
  fi

  rm -rf "$(soviez_stage_dir "$stage_id")"
  trap - EXIT
  soviez_retention_lock_release "$stage_id"
  unset SOVIEZ_RETENTION_HOLDING_LOCK
  soviez_retention_ok RETENTION_DELETED "Stage $stage_id deleted after retention expiry"
}

soviez_retention_status() {
  local stage_id="${1:-}"
  soviez_stage_paths_init
  if [[ -z "$stage_id" ]]; then
    local sid
    while IFS= read -r sid; do
      [[ -n "$sid" ]] || continue
      echo "--- $sid ---"
      soviez_retention_status "$sid" || true
    done < <(soviez_stage_inventory_list_ids)
    return 0
  fi
  soviez_retention_ensure "$stage_id"
  soviez_retention_refresh_derived "$stage_id"
  soviez_retention_render_banner "$stage_id" >/dev/null
  local rec
  rec="$(soviez_retention_read "$stage_id")"
  REC="$rec" TZNAME="$SOVIEZ_RETENTION_HOST_TZ" python3 - <<'PY'
import json, os
r=json.loads(os.environ["REC"])
print(json.dumps({
  "stage_id": r.get("stage_id"),
  "created_at": r.get("created_at"),
  "current_retention_deadline": r.get("current_retention_deadline"),
  "maximum_retention_deadline": r.get("maximum_retention_deadline"),
  "days_remaining": r.get("days_remaining"),
  "retention_status": r.get("retention_status"),
  "requested_extension_days": r.get("requested_extension_days"),
  "final_backup_status": r.get("final_backup_status"),
  "safe_shield_status": r.get("safe_shield_status"),
  "last_failure_code": r.get("last_failure_code"),
  "timezone": os.environ["TZNAME"],
}, indent=2))
PY
  echo "--- banner ---"
  cat "$(soviez_retention_banner_file "$stage_id")"
}

soviez_retention_retry() {
  local stage_id="$1" status
  soviez_retention_ensure "$stage_id"
  status="$(soviez_json_get "$(soviez_retention_read "$stage_id")" retention_status)"
  case "$status" in
    needs_action|deletion_blocked|recovery_required|failed_retryable|deletion_due)
      soviez_retention_run_deletion "$stage_id" 1
      ;;
    *)
      soviez_retention_die RETENTION_NOT_DUE "Nothing to retry (status=$status)"
      ;;
  esac
}

soviez_retention_scheduler_scan() {
  local sid days
  soviez_stage_paths_init
  while IFS= read -r sid; do
    [[ -n "$sid" ]] || continue
    soviez_retention_ensure "$sid" 2>/dev/null || continue
    soviez_retention_refresh_derived "$sid" || true
    soviez_retention_evaluate_warnings "$sid" || true
    soviez_retention_render_banner "$sid" >/dev/null || true
    days="$(soviez_json_get "$(soviez_retention_read "$sid")" days_remaining)"
    if [[ "$days" -le 0 ]]; then
      ( soviez_retention_run_deletion "$sid" 0 ) || true
    fi
  done < <(soviez_stage_inventory_list_ids)
}
