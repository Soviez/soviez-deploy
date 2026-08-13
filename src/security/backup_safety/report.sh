# shellcheck shell=bash
# Security Gate S5 — backup safety report (local-only).

soviez_s5_backup_report_write() {
  local evidence_dir="$1"
  local overall="${2:-UNKNOWN}"
  [[ -d "$evidence_dir" ]] || mkdir -p "$evidence_dir"
  mkdir -p "$evidence_dir/reports"
  local txt="$evidence_dir/reports/backup_report.txt"
  local js="$evidence_dir/reports/backup_report.json"
  local checks="$evidence_dir/checks/backup_validation.json"

  python3 - "$evidence_dir" "$overall" "$checks" "$txt" "$js" <<'PY'
import json,os,sys,datetime
edir,overall,checks_path,txt,js=sys.argv[1:6]
checks={}
if os.path.isfile(checks_path):
  try: checks=json.load(open(checks_path))
  except Exception: checks={}
obj={
  "gate":"S5",
  "kind":"backup_safety",
  "overall":overall,
  "generated_utc":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "checks":checks.get("checks",checks),
  "local_only_is_not_dr":True,
  "local_only":True,
  "telemetry":False,
}
lines=[
  "SOVIEZ SECURITY — BACKUP SAFETY (S5)",
  f"Overall: {overall}",
  f"Generated: {obj['generated_utc']}",
  "LOCAL_ONLY backup is NOT disaster-recovery capable.",
  "",
]
for k,v in sorted((obj["checks"] or {}).items()):
  lines.append(f"{k}: {v}")
lines += ["", "Local-only evidence. No telemetry."]
open(txt,"w").write("\n".join(lines)+"\n")
json.dump(obj, open(js,"w"), indent=2)
print(overall)
PY
  chmod 600 "$txt" "$js" 2>/dev/null || true
  printf '%s\n' "$js"
}
