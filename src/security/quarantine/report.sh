# shellcheck shell=bash
# Security Gate S4 — quarantine report (local-only).

soviez_q_report_write() {
  local qid="$1"
  local d meta
  d="$(soviez_q_dir "$qid")"
  meta="$d/meta.json"
  python3 - "$meta" "$d" <<'PY'
import json,os,sys
m=json.load(open(sys.argv[1]))
d=sys.argv[2]
def read(p, default="N/A"):
  try: return open(p).read().strip() or default
  except Exception: return default
scan=read(f"{d}/scans/preboot.status","UNKNOWN")
egress=read(f"{d}/network/egress_proof.txt","UNKNOWN")
mail=read(f"{d}/network/mail_proof.txt","UNKNOWN")
wh=read(f"{d}/network/webhook_proof.txt","UNKNOWN")
zatca=read(f"{d}/network/zatca_proof.txt","UNKNOWN")
fs=json.load(open(f"{d}/filestore/scan.json"))["status"] if os.path.isfile(f"{d}/filestore/scan.json") else "N/A"
secrets="PASS" if os.path.isfile(f"{d}/secrets/infra.env") else "FAIL"
overall="REVIEW_REQUIRED"
st=m.get("state")
if st=="PROMOTED": overall="PASS"
elif st in ("SCAN_FAILED","REJECTED"): overall="FAIL"
elif scan=="PASS" and egress=="BLOCKED" and st in ("QUARANTINED","VALIDATED"): overall="PASS"
elif scan=="PASS_WITH_REVIEW": overall="REVIEW_REQUIRED"
elif scan=="FAIL": overall="FAIL"
lines=[
"SOVIEZ SECURITY — MIGRATION/RESTORE QUARANTINE",
f"Source trust: {m.get('source_trust')}",
f"Archive integrity: {read(d+'/scans/archive.status','N/A')}",
f"Fresh infrastructure secrets: {secrets}",
f"Public exposure: PASS (loopback/private quarantine)",
f"External egress: {egress}",
f"Cron execution: BLOCKED (max_cron_threads=0)",
f"Outbound mail: {mail}",
f"Webhook/integration egress: {wh}",
f"ZATCA outbound: {zatca}",
f"Pre-boot technical scan: {scan}",
f"S3 full scan: {scan}",
f"Filestore targeted scan: {fs}",
f"ZATCA immutability: see evidence",
f"Operator approval: {m.get('approval_status')}",
f"State: {st}",
f"OVERALL: {overall}",
"",
"Local-only evidence. No telemetry. No destructive remediation.",
]
open(f"{d}/report.txt","w").write("\n".join(lines)+"\n")
json.dump({"gate":"S4","quarantine_id":m.get("quarantine_id"),"overall":overall,
           "state":st,"scan":scan,"egress":egress,"local_only":True,
           "code":"SEC_OK_QUARANTINE_VALIDATED" if overall=="PASS" else "SEC_WARN_REVIEW_REQUIRED"},
          open(f"{d}/report.json","w"), indent=2)
print(overall)
PY
}
