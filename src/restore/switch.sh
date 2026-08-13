# shellcheck shell=bash

soviez_restore_preserve_current() {
  # Args: op_id production_json
  local op_id="$1" prod="$2"
  local pdir db_path fs_path
  soviez_restore_paths_init
  pdir="$(soviez_restore_preserve_dir "$op_id")"
  mkdir -p "$pdir/db" "$pdir/filestore" "$pdir/config"
  chmod 700 "$pdir"
  printf '%s\n' "$prod" > "$pdir/config/production_identity.json"

  db_path="$(soviez_json_get "$prod" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod" filestore_path 2>/dev/null || true)"
  if [[ -n "$db_path" && -e "$db_path" ]]; then
    if [[ -d "$db_path" ]]; then
      cp -a "$db_path"/. "$pdir/db/" 2>/dev/null || true
    else
      cp -a "$db_path" "$pdir/db/dump" 2>/dev/null || true
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'preserved_db\n' > "$pdir/db/marker"
  fi
  if [[ -n "$fs_path" && -e "$fs_path" ]]; then
    cp -a "$fs_path"/. "$pdir/filestore/" 2>/dev/null || true
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'preserved_fs\n' > "$pdir/filestore/marker"
  fi

  local digest hours now
  digest="$(soviez_json_get "$prod" current_digest 2>/dev/null || soviez_json_get "$prod" image_digest 2>/dev/null || echo unknown)"
  hours="${SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS:-24}"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  SOVIEZ_OP="$op_id" SOVIEZ_D="$digest" SOVIEZ_H="$hours" SOVIEZ_NOW="$now" \
  SOVIEZ_T="$(soviez_json_get "$prod" tenant_id)" python3 - <<'PY' > "$pdir/rollback_manifest.json"
import json, os
from datetime import datetime, timedelta, timezone
hours = int(os.environ["SOVIEZ_H"])
try:
  dt = datetime.fromisoformat(os.environ["SOVIEZ_NOW"].replace("Z", "+00:00"))
except Exception:
  dt = datetime.now(timezone.utc)
expires = (dt + timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "tenant_id": os.environ["SOVIEZ_T"],
  "previous_digest": os.environ["SOVIEZ_D"],
  "created_at": os.environ["SOVIEZ_NOW"],
  "expires_at": expires,
  "safety_window_hours": hours,
}, separators=(",", ":")))
PY
  cat "$pdir/rollback_manifest.json"
}

soviez_restore_switch() {
  # Args: op_id production_json
  local op_id="$1" prod="$2"
  local cdir tenant_id runtime_dir
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  [[ -d "$cdir" ]] || soviez_restore_die RESTORE_SWITCH_FAILED "Candidate missing"

  # Security Gate S4 — untrusted restore cannot switch to Production until promoted
  if declare -F soviez_q_restore_block_switch_if_needed >/dev/null 2>&1; then
    if ! soviez_q_restore_block_switch_if_needed "${SOVIEZ_Q_ACTIVE_ID:-}"; then
      soviez_restore_die RESTORE_SWITCH_FAILED "S4 quarantine blocks Production switch"
    fi
  fi

  tenant_id="$(soviez_json_get "$prod" tenant_id)"
  runtime_dir="${SOVIEZ_TENANT_DIR:-${SOVIEZ_ROOT:-/var/soviez}/tenant}/$tenant_id"
  mkdir -p "$runtime_dir"

  if [[ "${SOVIEZ_RESTORE_FIXTURE_SWITCH_FAIL:-0}" == "1" ]]; then
    soviez_restore_die RESTORE_SWITCH_FAILED "Injected switch failure"
  fi

  local db_path fs_path
  db_path="$(soviez_json_get "$prod" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod" filestore_path 2>/dev/null || true)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    printf 'switched_from=%s\n' "$op_id" > "$runtime_dir/restore_switch.marker"
    if [[ -n "$db_path" ]]; then
      mkdir -p "$db_path"
      cp -a "$cdir/db/." "$db_path/" 2>/dev/null || true
    fi
    if [[ -n "$fs_path" ]]; then
      mkdir -p "$fs_path"
      cp -a "$cdir/filestore/." "$fs_path/" 2>/dev/null || true
    fi
  else
    # Promote candidate DB/filestore into recorded Production paths
    if [[ -n "$db_path" && -d "$cdir/db" ]]; then
      mkdir -p "$db_path"
      cp -a "$cdir/db/." "$db_path/" || soviez_restore_die RESTORE_SWITCH_FAILED "DB promote failed"
    fi
    if [[ -n "$fs_path" && -d "$cdir/filestore" ]]; then
      mkdir -p "$fs_path"
      cp -a "$cdir/filestore/." "$fs_path/" || soviez_restore_die RESTORE_SWITCH_FAILED "Filestore promote failed"
    fi
  fi

  local digest
  digest="$(cat "$cdir/config/image_digest.txt" 2>/dev/null | sed -n 's/^digest=//p' || echo restored)"
  printf '%s' "$digest" > "$runtime_dir/current_digest.txt"
  printf '%s' '{"ok":true,"switched":true}'
}
