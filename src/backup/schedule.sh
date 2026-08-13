# shellcheck shell=bash

# Default schedule: 02:00 server-local timezone

soviez_backup_schedule_default_hour() { printf '2\n'; }
soviez_backup_schedule_default_minute() { printf '0\n'; }

soviez_backup_schedule_write() {
  local obj="$1"
  local sid
  sid="$(soviez_json_get "$obj" schedule_id)"
  [[ -n "$sid" ]] || soviez_backup_die BACKUP_SCHEDULE_INVALID "schedule_id required"
  soviez_backup_paths_init
  local f
  f="$(soviez_backup_schedule_file "$sid")"
  printf '%s\n' "$obj" > "$f"
  chmod 644 "$f"
  printf '%s' "$obj"
}

soviez_backup_schedule_add() {
  # Args: production_id [destination_profile] [hour] [minute]
  local prod_id="$1" dest="${2:-local-primary}" hour="${3:-2}" minute="${4:-0}"
  [[ -n "$prod_id" ]] || soviez_backup_die BACKUP_TARGET_REQUIRED "production_id required"
  local sid tz now
  sid="sched-${prod_id}-daily"
  tz="$(date +%Z 2>/dev/null || echo local)"
  if declare -F soviez_utc_now >/dev/null 2>&1; then now="$(soviez_utc_now)"; else now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; fi
  SOVIEZ_SID="$sid" SOVIEZ_P="$prod_id" SOVIEZ_D="$dest" SOVIEZ_H="$hour" \
  SOVIEZ_M="$minute" SOVIEZ_TZ="$tz" SOVIEZ_NOW="$now" python3 - <<'PY' | {
import json, os
print(json.dumps({
  "schedule_id": os.environ["SOVIEZ_SID"],
  "production_id": os.environ["SOVIEZ_P"],
  "enabled": True,
  "cadence": "daily",
  "hour_local": int(os.environ["SOVIEZ_H"]),
  "minute_local": int(os.environ["SOVIEZ_M"]),
  "timezone": os.environ["SOVIEZ_TZ"],
  "destination_profile": os.environ["SOVIEZ_D"],
  "backup_type": "full",
  "resource_profile": "balanced",
  "created_at": os.environ["SOVIEZ_NOW"],
}, separators=(",", ":")))
PY
    local obj
    obj="$(cat)"
    soviez_backup_schedule_write "$obj"
  }
}

soviez_backup_schedule_list() {
  soviez_backup_paths_init
  SOVIEZ_DIR="$SOVIEZ_BACKUP_SCHEDULE_DIR" python3 - <<'PY'
import json, os, glob
out = []
for path in sorted(glob.glob(os.path.join(os.environ["SOVIEZ_DIR"], "*.json"))):
  with open(path, encoding="utf-8") as fh:
    out.append(json.load(fh))
print(json.dumps({"ok": True, "schedules": out}, separators=(",", ":")))
PY
}

soviez_backup_schedule_show() {
  local sid="$1"
  local f
  f="$(soviez_backup_schedule_file "$sid")"
  [[ -f "$f" ]] || soviez_backup_die BACKUP_SCHEDULE_INVALID "Unknown schedule: $sid"
  cat "$f"
}

soviez_backup_schedule_set_enabled() {
  local sid="$1" enabled="$2"
  local f obj
  f="$(soviez_backup_schedule_file "$sid")"
  [[ -f "$f" ]] || soviez_backup_die BACKUP_SCHEDULE_INVALID "Unknown schedule: $sid"
  obj="$(SOVIEZ_O="$(cat "$f")" SOVIEZ_E="$enabled" python3 - <<'PY'
import json, os
o = json.loads(os.environ["SOVIEZ_O"])
o["enabled"] = os.environ["SOVIEZ_E"] in ("1", "true", "True")
print(json.dumps(o, separators=(",", ":")))
PY
)"
  soviez_backup_schedule_write "$obj" >/dev/null
  printf '%s\n' "$obj"
}

soviez_backup_schedule_remove() {
  local sid="$1"
  local f
  f="$(soviez_backup_schedule_file "$sid")"
  [[ -f "$f" ]] || soviez_backup_die BACKUP_SCHEDULE_INVALID "Unknown schedule: $sid"
  rm -f "$f"
  soviez_backup_ok BACKUP_SCHEDULE_REMOVED "Removed $sid"
}

soviez_backup_schedule_due_now() {
  # Returns schedule JSON lines that are due at current local hour:minute
  local hour minute
  hour="$(date +%H | sed 's/^0//')"
  minute="$(date +%M | sed 's/^0//')"
  hour="${hour:-0}"
  minute="${minute:-0}"
  SOVIEZ_DIR="$SOVIEZ_BACKUP_SCHEDULE_DIR" SOVIEZ_H="$hour" SOVIEZ_M="$minute" python3 - <<'PY'
import json, os, glob
h = int(os.environ["SOVIEZ_H"]); m = int(os.environ["SOVIEZ_M"])
for path in sorted(glob.glob(os.path.join(os.environ["SOVIEZ_DIR"], "*.json"))):
  with open(path, encoding="utf-8") as fh:
    s = json.load(fh)
  if not s.get("enabled"):
    continue
  if int(s.get("hour_local", -1)) == h and int(s.get("minute_local", -1)) == m:
    print(json.dumps(s, separators=(",", ":")))
PY
}

soviez_backup_schedule_tick() {
  # Called from ops scheduler
  soviez_backup_paths_init
  local line prod dest
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    prod="$(soviez_json_get "$line" production_id)"
    dest="$(soviez_json_get "$line" destination_profile 2>/dev/null || echo local-primary)"
    if declare -F soviez_backup_run >/dev/null 2>&1; then
      ( soviez_backup_run "$prod" "$dest" full 1 ) || true
    fi
  done < <(soviez_backup_schedule_due_now)

  # Retention tick (dry-run false only when SOVIEZ_BACKUP_RETENTION_AUTO=1)
  if [[ "${SOVIEZ_BACKUP_RETENTION_AUTO:-0}" == "1" ]] && declare -F soviez_backup_retention_cleanup >/dev/null 2>&1; then
    ( soviez_backup_retention_cleanup 0 "" 1 ) || true
  fi
}
