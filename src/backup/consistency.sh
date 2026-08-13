# shellcheck shell=bash

soviez_backup_quiesce_marker() {
  local prod_id="$1"
  soviez_backup_paths_init
  printf '%s/quiesce-%s.marker\n' "$SOVIEZ_BACKUP_STAGING_DIR" "$prod_id"
}

soviez_backup_quiesce_begin() {
  # Args: production_id [reason]
  local prod_id="$1" reason="${2:-production_backup}"
  local marker started
  marker="$(soviez_backup_quiesce_marker "$prod_id")"
  started="$(date +%s 2>/dev/null || echo 0)"
  mkdir -p "$(dirname "$marker")"
  SOVIEZ_P="$prod_id" SOVIEZ_R="$reason" SOVIEZ_S="$started" python3 - <<'PY' > "$marker"
import json, os
print(json.dumps({
  "production_id": os.environ["SOVIEZ_P"],
  "reason": os.environ["SOVIEZ_R"],
  "started_epoch": int(os.environ["SOVIEZ_S"]),
  "status": "quiesced",
}, separators=(",", ":")))
PY
  chmod 600 "$marker"

  if [[ -n "${SOVIEZ_BACKUP_QUIESCE_CMD:-}" ]]; then
    # shellcheck disable=SC2086
    if ! eval "$SOVIEZ_BACKUP_QUIESCE_CMD" "$prod_id" >/dev/null 2>&1; then
      rm -f "$marker"
      soviez_backup_die BACKUP_QUIESCE_FAILED "Quiesce command failed for $prod_id"
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Fixture: marker alone is enough
    :
  else
    # Best-effort: disable cron-like markers under tenant if present
    local tenant_dir="${SOVIEZ_TENANT_DIR:-${SOVIEZ_ROOT:-/var/soviez}/tenant}/$prod_id"
    if [[ -d "$tenant_dir" ]]; then
      mkdir -p "$tenant_dir/runtime"
      printf 'quiesced=1\nreason=%s\n' "$reason" > "$tenant_dir/runtime/backup_quiesce.env"
    fi
  fi
  printf '%s' "$started"
}

soviez_backup_quiesce_end() {
  # Args: production_id started_epoch
  local prod_id="$1" started="${2:-0}"
  local marker ended duration
  marker="$(soviez_backup_quiesce_marker "$prod_id")"
  ended="$(date +%s 2>/dev/null || echo 0)"
  if [[ "$started" =~ ^[0-9]+$ && "$ended" =~ ^[0-9]+$ ]]; then
    duration=$(( ended - started ))
    [[ "$duration" -ge 0 ]] || duration=0
  else
    duration=0
  fi

  if [[ -n "${SOVIEZ_BACKUP_RESUME_CMD:-}" ]]; then
    # shellcheck disable=SC2086
    if ! eval "$SOVIEZ_BACKUP_RESUME_CMD" "$prod_id" >/dev/null 2>&1; then
      soviez_backup_die BACKUP_RESUME_FAILED "Failed to resume application for $prod_id"
    fi
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    :
  else
    local tenant_dir="${SOVIEZ_TENANT_DIR:-${SOVIEZ_ROOT:-/var/soviez}/tenant}/$prod_id"
    rm -f "$tenant_dir/runtime/backup_quiesce.env" 2>/dev/null || true
  fi

  if [[ -f "$marker" ]]; then
    SOVIEZ_M="$(cat "$marker")" SOVIEZ_D="$duration" SOVIEZ_E="$ended" python3 - <<'PY' > "$marker"
import json, os
m = json.loads(os.environ["SOVIEZ_M"])
m["status"] = "resumed"
m["ended_epoch"] = int(os.environ["SOVIEZ_E"])
m["pause_seconds"] = int(os.environ["SOVIEZ_D"])
print(json.dumps(m, separators=(",", ":")))
PY
  fi
  printf '%s' "$duration"
}

soviez_backup_quiesce_pause_seconds() {
  local prod_id="$1"
  local marker
  marker="$(soviez_backup_quiesce_marker "$prod_id")"
  [[ -f "$marker" ]] || { printf '0\n'; return 0; }
  soviez_json_get "$(cat "$marker")" pause_seconds 2>/dev/null || echo 0
}
