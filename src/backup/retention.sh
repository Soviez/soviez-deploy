# shellcheck shell=bash

# Retention: 7 daily / 4 weekly / 12 monthly classification.
# Protects pinned, latest successful/verified/restore_tested, active ops.

soviez_backup_retention_classify() {
  # Args: optional production_id filter
  local prod_filter="${1:-}"
  local idx
  idx="$(soviez_backup_inventory_load)"
  SOVIEZ_IDX="$idx" SOVIEZ_P="$prod_filter" python3 - <<'PY'
import json, os
from datetime import datetime, timezone, timedelta

idx = json.loads(os.environ["SOVIEZ_IDX"])
pf = os.environ.get("SOVIEZ_P") or ""
backs = idx.get("backups", [])
if pf:
  backs = [b for b in backs if b.get("production_id") == pf]

def parse_ts(s):
  if not s:
    return datetime.min.replace(tzinfo=timezone.utc)
  try:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))
  except Exception:
    return datetime.min.replace(tzinfo=timezone.utc)

# Group by production
by_prod = {}
for b in backs:
  by_prod.setdefault(b.get("production_id") or "", []).append(b)

results = []
for prod, items in by_prod.items():
  items = sorted(items, key=lambda x: parse_ts(x.get("created_at")), reverse=True)
  latest_ok = next((b for b in items if b.get("status") in ("completed", "verified", "ok")), None)
  latest_ver = next((b for b in items if b.get("verification_status") == "VERIFIED"), None)
  latest_rt = next((b for b in items if b.get("restore_test_status") == "RESTORE_TESTED"), None)

  daily, weekly, monthly = [], [], []
  seen_days, seen_weeks, seen_months = set(), set(), set()
  for b in items:
    dt = parse_ts(b.get("created_at"))
    day = dt.strftime("%Y-%m-%d")
    week = dt.strftime("%G-W%V")
    month = dt.strftime("%Y-%m")
    classes = []
    if b.get("pinned"):
      classes.append("pinned")
    if latest_ok and b.get("backup_id") == latest_ok.get("backup_id"):
      classes.append("latest_successful")
    if latest_ver and b.get("backup_id") == latest_ver.get("backup_id"):
      classes.append("latest_verified")
    if latest_rt and b.get("backup_id") == latest_rt.get("backup_id"):
      classes.append("latest_restore_tested")
    if day not in seen_days and len(daily) < 7:
      seen_days.add(day); daily.append(b); classes.append("daily_keep")
    if week not in seen_weeks and len(weekly) < 4:
      seen_weeks.add(week); weekly.append(b); classes.append("weekly_keep")
    if month not in seen_months and len(monthly) < 12:
      seen_months.add(month); monthly.append(b); classes.append("monthly_keep")
    if not classes:
      classes.append("eligible_for_deletion")
    results.append({
      "backup_id": b.get("backup_id"),
      "production_id": prod,
      "created_at": b.get("created_at"),
      "classes": classes,
      "eligible_for_deletion": classes == ["eligible_for_deletion"],
    })

print(json.dumps({"ok": True, "classifications": results}, separators=(",", ":")))
PY
}

soviez_backup_retention_cleanup() {
  # Args: dry_run(0|1) [production_id] [confirm]
  local dry_run="${1:-1}" prod_filter="${2:-}" confirm="${3:-0}"
  if [[ "$dry_run" != "1" && "$confirm" != "1" && "${SOVIEZ_BACKUP_ASSUME_YES:-0}" != "1" ]]; then
    if [[ ! -t 0 ]]; then
      soviez_backup_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Retention cleanup requires --confirm"
    fi
  fi

  local classed deleted=0 protected=0
  classed="$(soviez_backup_retention_classify "$prod_filter")"
  SOVIEZ_C="$classed" SOVIEZ_DRY="$dry_run" python3 - <<'PY' > /tmp/soviez-backup-retention-plan.$$
import json, os
c = json.loads(os.environ["SOVIEZ_C"])
dry = os.environ.get("SOVIEZ_DRY") == "1"
plan = []
for row in c.get("classifications", []):
  if row.get("eligible_for_deletion"):
    plan.append({"backup_id": row["backup_id"], "production_id": row["production_id"], "action": "delete"})
  else:
    plan.append({"backup_id": row["backup_id"], "production_id": row["production_id"],
                 "action": "keep", "classes": row.get("classes")})
print(json.dumps({"dry_run": dry, "plan": plan}, separators=(",", ":")))
PY
  local plan
  plan="$(cat /tmp/soviez-backup-retention-plan.$$)"
  rm -f /tmp/soviez-backup-retention-plan.$$

  if [[ "$dry_run" == "1" ]]; then
    printf '%s\n' "$plan"
    return 0
  fi

  # Exact deletes only (no broad rm)
  local delete_list prod_id backup_id obj pinned bdir
  delete_list="$(SOVIEZ_PLAN="$plan" python3 - <<'PY'
import json, os
plan = json.loads(os.environ["SOVIEZ_PLAN"])
for row in plan.get("plan", []):
  if row.get("action") == "delete":
    print(f'{row["production_id"]}\t{row["backup_id"]}')
PY
)"
  while IFS=$'\t' read -r prod_id backup_id; do
    [[ -n "${backup_id:-}" ]] || continue
    obj="$(soviez_backup_read_object "$prod_id" "$backup_id" 2>/dev/null || true)"
    [[ -n "$obj" ]] || continue
    pinned="$(soviez_json_get "$obj" pinned 2>/dev/null || echo false)"
    if [[ "$pinned" == "true" || "$pinned" == "True" || "$pinned" == "1" ]]; then
      protected=$((protected + 1))
      continue
    fi
    bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
    # Exact remote object/file deletes when destination recorded (never recursive)
    local dest_profile dest_json dest_kind fname
    dest_profile="$(soviez_json_get "$obj" destination_profile 2>/dev/null || true)"
    if [[ -n "$dest_profile" ]] && declare -F soviez_backup_destination_resolve >/dev/null 2>&1; then
      dest_json="$(soviez_backup_destination_resolve "$dest_profile" 2>/dev/null || true)"
      dest_kind="$(soviez_json_get "$dest_json" kind 2>/dev/null || true)"
      if [[ -d "$bdir" ]]; then
        shopt -s nullglob
        for fname in "$bdir"/*; do
          [[ -f "$fname" ]] || continue
          case "$dest_kind" in
            s3)
              declare -F soviez_backup_s3_dest_delete_exact >/dev/null 2>&1 \
                && soviez_backup_s3_dest_delete_exact "$dest_json" "$prod_id" "$backup_id" "$(basename "$fname")" >/dev/null 2>&1 || true
              ;;
            sftp)
              declare -F soviez_backup_sftp_dest_delete_exact >/dev/null 2>&1 \
                && soviez_backup_sftp_dest_delete_exact "$dest_json" "$prod_id" "$backup_id" "$(basename "$fname")" >/dev/null 2>&1 || true
              ;;
          esac
        done
        shopt -u nullglob
      fi
    fi
    case "$bdir" in
      "$SOVIEZ_BACKUP_DATA_DIR"/*)
        # Exact backup directory only (ownership already constrained by paths helper)
        rm -rf "$bdir"
        soviez_backup_inventory_remove "$backup_id"
        deleted=$((deleted + 1))
        ;;
      *)
        protected=$((protected + 1))
        ;;
    esac
  done <<< "$delete_list"

  SOVIEZ_D="$deleted" SOVIEZ_P="$protected" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "BACKUP_RETENTION_CLEANUP",
  "deleted": int(os.environ["SOVIEZ_D"]),
  "protected": int(os.environ["SOVIEZ_P"]),
}, separators=(",", ":")))
PY
}
