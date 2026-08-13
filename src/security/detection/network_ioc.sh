# shellcheck shell=bash
# Security Gate S3 — lightweight network IOC observation (ss/proc; no capture).

soviez_s3_network_ioc_scan() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="$(mktemp)"
  local share iocs
  share="$(soviez_s3_detection_share)"
  iocs="${share}/iocs.json"
  python3 - "$iocs" "$out" <<'PY'
import json,subprocess,sys,re
iocs=json.load(open(sys.argv[1])).get("iocs") or []
bad_doms={i["value"].lower() for i in iocs if i.get("type") in ("domain","url","ipv4")}
# Also extract hosts from URLs
for i in list(bad_doms):
  m=re.search(r"https?://([^/:]+)", i)
  if m: bad_doms.add(m.group(1).lower())
conn=""
try:
  conn=subprocess.check_output(["ss","-tunap"], text=True, errors="replace")
except Exception:
  try:
    conn=subprocess.check_output(["netstat","-tunap"], text=True, errors="replace")
  except Exception:
    conn=""
findings=[]
low=conn.lower()
for b in bad_doms:
  if b and b in low:
    findings.append({"severity":"CRITICAL","code":"SEC_HIGH_KNOWN_BAD_ENDPOINT","indicator":b})
status="PASS" if not findings else "FAIL"
json.dump({"status":status,"findings":findings,"method":"ss_or_netstat","packet_capture":False}, open(sys.argv[2],"w"), indent=2)
print(status)
PY
}
