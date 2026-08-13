# shellcheck shell=bash

soviez_migration_transfer_backup_gate() {
  local pair_id="${1:-}" op_id="${2:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  local backup_json="" status classification verified_at age_s now pin_path
  now="$(soviez_migration_now_epoch)"

  if [[ -n "${SOVIEZ_MIG_FIXTURE_BACKUP_JSON:-}" ]]; then
    backup_json="$SOVIEZ_MIG_FIXTURE_BACKUP_JSON"
  elif [[ -n "${SOVIEZ_MIG_FIXTURE_BACKUP_PATH:-}" && -f "${SOVIEZ_MIG_FIXTURE_BACKUP_PATH}" ]]; then
    backup_json="$(cat "$SOVIEZ_MIG_FIXTURE_BACKUP_PATH")"
  else
    # Prefer latest verified backup metadata under SOVIEZ_BACKUP_ROOT if present
    if [[ -n "${SOVIEZ_BACKUP_ROOT:-}" && -d "${SOVIEZ_BACKUP_ROOT}" ]]; then
      backup_json="$(SOVIEZ_B="$SOVIEZ_BACKUP_ROOT" python3 - <<'PY'
import json, os, pathlib
root=pathlib.Path(os.environ["SOVIEZ_B"])
best=None; best_ts=""
for p in root.rglob("*.json"):
  try: d=json.loads(p.read_text())
  except Exception: continue
  st=(d.get("status") or d.get("verification_status") or "").upper()
  cl=(d.get("classification") or "").lower()
  if st not in ("VERIFIED","RESTORE_TESTED") and cl not in ("recent_verified","verified"):
    continue
  ts=d.get("verified_at") or d.get("completed_at") or d.get("created_at") or ""
  if ts>=best_ts:
    best_ts=ts; best=d
print(json.dumps(best) if best else "")
PY
)"
    fi
  fi

  [[ -n "$backup_json" ]] || soviez_migration_die MIGRATION_SOURCE_BACKUP_REQUIRED "No verified full backup found"

  status="$(soviez_json_get "$backup_json" status 2>/dev/null || true)"
  classification="$(soviez_json_get "$backup_json" classification 2>/dev/null || true)"
  status="${status:-}"
  classification="${classification:-}"
  local ok=0 status_u classification_l
  status_u="$(printf '%s' "$status" | tr '[:lower:]' '[:upper:]')"
  classification_l="$(printf '%s' "$classification" | tr '[:upper:]' '[:lower:]')"
  case "$status_u" in
    VERIFIED|RESTORE_TESTED) ok=1 ;;
  esac
  case "$classification_l" in
    recent_verified|verified) ok=1 ;;
  esac
  [[ "$ok" == "1" ]] || soviez_migration_die MIGRATION_SOURCE_BACKUP_NOT_VERIFIED "Backup not VERIFIED (status=$status classification=$classification)"

  verified_at="$(soviez_json_get "$backup_json" verified_at 2>/dev/null || true)"
  [[ -n "$verified_at" && "$verified_at" != "null" ]] || \
    verified_at="$(soviez_json_get "$backup_json" completed_at 2>/dev/null || true)"
  [[ -n "$verified_at" && "$verified_at" != "null" ]] || \
    verified_at="$(soviez_json_get "$backup_json" created_at 2>/dev/null || true)"
  if [[ -z "$verified_at" || "$verified_at" == "null" ]]; then
    # Fixture may supply age_seconds / latest_verified_age_seconds directly
    age_s="$(soviez_json_get "$backup_json" age_seconds 2>/dev/null || true)"
    [[ -n "$age_s" && "$age_s" != "null" ]] || \
      age_s="$(soviez_json_get "$backup_json" latest_verified_age_seconds 2>/dev/null || true)"
    [[ -n "$age_s" && "$age_s" != "null" ]] || age_s=0
  else
    age_s=$(( now - $(soviez_migration_iso_to_epoch "$verified_at") ))
  fi
  local max_age="${SOVIEZ_MIG_BACKUP_MAX_AGE_SECONDS:-86400}"
  [[ "$age_s" -le "$max_age" ]] || soviez_migration_die MIGRATION_SOURCE_BACKUP_TOO_OLD "Backup age ${age_s}s exceeds ${max_age}s"

  # Pin flag into transfer op local state (or pair-scoped pin file)
  local pin_dir backup_id
  backup_id="$(soviez_json_get "$backup_json" backup_id 2>/dev/null || true)"
  [[ -n "$backup_id" && "$backup_id" != "null" ]] || backup_id="backup-unknown"
  if [[ -n "$op_id" ]]; then
    pin_dir="$(soviez_migration_transfer_op_dir "$op_id")"
  else
    pin_dir="$(soviez_migration_transfer_op_dir "pin-$pair_id")"
  fi
  mkdir -p "$pin_dir"
  pin_path="$pin_dir/backup_pin.json"
  SOVIEZ_B="$backup_json" SOVIEZ_P="$pair_id" SOVIEZ_BID="$backup_id" SOVIEZ_OUT="$pin_path" python3 - <<'PY'
import json, os, datetime
b=json.loads(os.environ["SOVIEZ_B"])
doc={
  "schema_version":"soviez.migration_backup_pin.v1",
  "migration_pair_id": os.environ["SOVIEZ_P"],
  "backup_id": os.environ["SOVIEZ_BID"],
  "status": b.get("status") or b.get("verification_status") or "VERIFIED",
  "classification": b.get("classification") or "recent_verified",
  "pinned": True,
  "pin_through_phases": ["19","20","21"],
  "retention_protected": True,
  "pinned_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "backup": {k:b.get(k) for k in ("backup_id","production_id","license_id","database_uuid","verified_at","completed_at","created_at","classification","status","age_seconds") if b.get(k) is not None},
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY
}
