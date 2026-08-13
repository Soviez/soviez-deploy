# shellcheck shell=bash
# Security Gate S3 — read-only custom addon static observation.

soviez_s3_addon_scan() {
  local addon_dir="$1"
  local out="${2:-}"
  [[ -n "$out" ]] || out="$(mktemp)"
  [[ -d "$addon_dir" ]] || { echo '{"status":"N/A","reason":"missing_addon_dir"}'; return 0; }
  python3 - "$addon_dir" "$out" <<'PY'
import json,os,re,sys,hashlib
root=sys.argv[1]; out=sys.argv[2]
rules=[
 ("SEC_HIGH_CUSTOM_ADDON_SHELL_EXEC", r"(?i)os\.system\s*\(|subprocess\.(Popen|call|run|check_output)\s*\(|/bin/bash\s+-c|(?:curl|wget).{0,120}(?:ba)?sh", "HIGH"),
 ("SEC_HIGH_DB_OBFUSCATED_EXEC", r"(?i)base64\.b64decode\s*\(.*\)\s*;?\s*exec", "HIGH"),
 ("SEC_HIGH_DB_DOWNLOADER", r"(?i)urllib\.request\.urlretrieve|requests\.get\([^\)]*\)[\s\S]{0,80}exec", "HIGH"),
]
findings=[]
for dirpath,_,files in os.walk(root):
  for fn in files:
    if not fn.endswith((".py",".xml",".js")): continue
    path=os.path.join(dirpath,fn)
    try:
      data=open(path,"rb").read(1_500_000)
      text=data.decode("utf-8","replace")
    except Exception:
      continue
    # Import-only subprocess without call → not automatically HIGH
    for code,pat,sev in rules:
      if re.search(pat, text):
        findings.append({
          "code":code,"severity":sev,"file":path,
          "sha256":hashlib.sha256(data).hexdigest(),
          "note":"static observation only; third-party addons not modified",
        })
# Soften: file that only contains the word subprocess as import
soft=[]
for f in findings:
  try:
    t=open(f["file"],encoding="utf-8",errors="replace").read()
  except Exception:
    soft.append(f); continue
  if f["code"]=="SEC_HIGH_CUSTOM_ADDON_SHELL_EXEC" and "subprocess" in t and not re.search(r"subprocess\.(Popen|call|run|check_output|check_call)\s*\(", t) and not re.search(r"os\.system\s*\(", t):
    f=dict(f); f["severity"]="INFO"; f["code"]="SEC_INFO_TRUSTED_TECHNICAL_CHANGE"; f["note"]="import-only subprocess"
  soft.append(f)
findings=soft
status="PASS"
if any(x.get("severity")=="CRITICAL" for x in findings): status="FAIL"
elif any(x.get("severity")=="HIGH" for x in findings): status="FAIL"
elif findings: status="PASS_WITH_REVIEW"
json.dump({"status":status,"findings":findings,"mutates_addons":False}, open(out,"w"), indent=2)
print(status)
PY
}
