# shellcheck shell=bash

soviez_image_collect_references() {
  # Host-wide reference scan → JSON array of {digest,source,detail}
  python3 - <<'PY'
import json, os, subprocess, glob

def run(cmd):
  try:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
  except Exception:
    return ""

refs=[]
# Docker containers (running + stopped)
out=run(["docker","ps","-a","--no-trunc","--format","{{.ID}}\t{{.Image}}\t{{.State}}\t{{.Names}}"])
for line in out.splitlines():
  parts=line.split("\t")
  if len(parts)<4: continue
  cid,image,state,name=parts[0],parts[1],parts[2],parts[3]
  # resolve image id
  try:
    iid=subprocess.check_output(["docker","inspect",cid,"--format","{{.Image}}"], text=True).strip()
  except Exception:
    iid=image
  src="running_container" if state=="running" else "stopped_container"
  refs.append({"digest":iid,"source":src,"detail":name,"container_id":cid,"state":state})

root=os.environ.get("SOVIEZ_ROOT") or os.environ.get("SOVIEZ_OPS_ROOT") or ""
tenant=os.environ.get("SOVIEZ_TENANT_DIR") or (os.path.join(root,"tenant") if root else "/var/soviez/tenant")
stages=os.environ.get("SOVIEZ_STAGES_DIR") or (os.path.join(root,"stages") if root else "/var/soviez/stages")
updates=os.environ.get("SOVIEZ_UPDATE_ROOT") or (os.path.join(root,"updates") if root else "/var/soviez/ops/updates")
ops=os.environ.get("SOVIEZ_OPS_ROOT") or (os.path.join(root,"ops") if root else "/var/soviez/ops")

def add_from_json(path, source, keys):
  try:
    d=json.load(open(path))
  except Exception:
    return
  for k in keys:
    v=d.get(k)
    if isinstance(v,str) and v:
      refs.append({"digest":v,"source":source,"detail":path})

for p in glob.glob(os.path.join(tenant,"**/identity.json"), recursive=True):
  add_from_json(p,"production_inventory",["current_digest","image_digest","previous_digest","rollback_digest"])
for p in glob.glob(os.path.join(stages,"**/identity.json"), recursive=True):
  add_from_json(p,"stage_inventory",["current_digest","image_digest","release_digest","digest"])
for p in glob.glob(os.path.join(updates,"candidates/*/candidate.json")):
  add_from_json(p,"candidate",["target_digest"])
for p in glob.glob(os.path.join(updates,"backups/*/rollback_manifest.json")):
  add_from_json(p,"rollback_manifest",["previous_digest","current_digest"])
for p in glob.glob(os.path.join(ops,"operations/*/canonical.json")) + glob.glob(os.path.join(ops,"registry/index/*.json")):
  try:
    d=json.load(open(p))
  except Exception:
    continue
  state=d.get("current_state") or ""
  if state in ("completed","canceled","failed_terminal"):
    continue
  meta=d.get("meta") or {}
  for k in ("target_digest","current_digest","previous_digest","image_digest","rollback_digest"):
    v=d.get(k) or meta.get(k)
    if v:
      src="active_operation" if state!="recovery_required" else "recovery"
      refs.append({"digest":v,"source":src,"detail":p,"operation_state":state})

print(json.dumps({"references":refs},separators=(",",":")))
PY
}
