# shellcheck shell=bash
# Security Gate S3 — multi-signal process / miner detection (read-only; no kill).

soviez_s3_process_scan() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="$(mktemp)"
  python3 - "$out" <<'PY'
import json,os,re,subprocess,time,sys
out=sys.argv[1]
# Sample process table twice for sustained CPU signal (bounded)
def snapshot():
  cmds=[
    ["ps","-eo","pid,ppid,user,pcpu,pmem,command","--sort=-pcpu"],
    ["ps","-axo","pid,ppid,user,%cpu,command"],
    ["ps","-axo","pid,ppid,user,pcpu,command"],
  ]
  raw=""
  for c in cmds:
    try:
      raw=subprocess.check_output(c, text=True, errors="replace", stderr=subprocess.DEVNULL)
      break
    except Exception:
      continue
  rows=[]
  for line in raw.splitlines()[1:40]:
    parts=line.split(None,5)
    if len(parts)<5: continue
    if len(parts)<6: parts=parts+[""]
    pid,ppid,user,pcpu=parts[0],parts[1],parts[2],parts[3]
    cmd=parts[-1]
    try: cpu=float(str(pcpu).replace("%",""))
    except Exception: cpu=0.0
    rows.append({"pid":pid,"ppid":ppid,"user":user,"pcpu":cpu,"cmd":cmd})
  return rows

s1=snapshot()
time.sleep(0.4)
s2=snapshot()
by_pid={r["pid"]:r for r in s2}
findings=[]
ioc_names={"xmrig","minerd","cpuminer","kworkerds"}
for r in s2:
  cmd=(r.get("cmd") or "").lower()
  path_tmp = "/tmp/" in cmd or "/dev/shm/" in cmd or "/var/tmp/" in cmd
  name_hit=any(n in cmd for n in ioc_names)
  stratum="stratum+tcp://" in cmd or "stratum+ssl://" in cmd
  # Multi-signal miner
  if name_hit and (stratum or path_tmp):
    findings.append({"severity":"CRITICAL","code":"SEC_CRIT_HOST_ACTIVE_MINER","pid":r["pid"],"cmd":r["cmd"][:200]})
  elif name_hit:
    findings.append({"severity":"HIGH","code":"SEC_CRIT_HOST_ACTIVE_MINER","pid":r["pid"],"cmd":r["cmd"][:200],"note":"name-only"})
  elif stratum:
    findings.append({"severity":"HIGH","code":"SEC_HIGH_KNOWN_BAD_ENDPOINT","pid":r["pid"],"cmd":r["cmd"][:200]})
  elif path_tmp and (
      re.search(r"\bcurl\b.*\bhttp", cmd)
      or re.search(r"\bwget\b.*\bhttp", cmd)
      or ("bash -c" in cmd and "http" in cmd)
      or ("python" in cmd and "http" in cmd)
  ):
    findings.append({"severity":"HIGH","code":"SEC_HIGH_DB_DOWNLOADER","pid":r["pid"],"cmd":r["cmd"][:200]})
  # CPU alone must NOT classify malware
  # (documented: high pcpu postgres/odoo ignored here)

status="PASS"
if any(f.get("severity")=="CRITICAL" for f in findings):
  status="FAIL"
elif findings:
  status="PASS_WITH_REVIEW"
json.dump({"status":status,"findings":findings,"policy":"cpu_alone_not_malware","destructive":False}, open(out,"w"), indent=2)
print(status)
PY
}
