# shellcheck shell=bash

soviez_image_classify() {
  local current_digest="${1:-}" rollback_digest="${2:-}" refs_json="${3:-}"
  [[ -n "$refs_json" ]] || refs_json="$(soviez_image_collect_references)"
  local images_json="[]"
  if soviez_image_docker_available; then
    images_json="$(soviez_image_list_soviez_erp | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()]))')"
  fi
  SOVIEZ_CUR="$current_digest" SOVIEZ_RB="$rollback_digest" SOVIEZ_REFS="$refs_json" SOVIEZ_IMGS="$images_json" python3 - <<'PY'
import json,os
cur=os.environ.get("SOVIEZ_CUR") or ""
rb=os.environ.get("SOVIEZ_RB") or ""
refs=json.loads(os.environ["SOVIEZ_REFS"]).get("references",[])
imgs=json.loads(os.environ["SOVIEZ_IMGS"] or "[]")

def norm(d):
  if not d: return ""
  d=d.strip()
  if d.startswith("sha256:"): return d
  if len(d)==64: return "sha256:"+d
  return d

cur,rb=norm(cur),norm(rb)
out=[]
for img in imgs:
  iid=norm(img.get("image_id") or img.get("digest") or "")
  labels=img.get("labels") or {}
  classif="eligible_for_cleanup"
  reasons=[]
  if not labels.get("com.soviez.managed") or labels.get("com.soviez.product")!="erp":
    classif="ownership_ambiguous"; reasons.append("IMAGE_CLEANUP_OWNERSHIP_AMBIGUOUS")
  if not labels.get("com.soviez.release-id"):
    classif="ownership_ambiguous"; reasons.append("IMAGE_CLEANUP_LABEL_MISSING")
  ld=labels.get("com.soviez.image-digest")
  if ld and ld not in (iid, iid.replace("sha256:",""), img.get("release_id")) and not iid.endswith(str(ld)[-12:] if ld else ""):
    # soft mismatch note only when explicit digest label differs from id prefix
    pass
  if iid==cur or (cur and cur in iid):
    classif="current"; reasons=["IMAGE_CLEANUP_CURRENT_IMAGE_PROTECTED"]
  elif iid==rb or (rb and rb in iid):
    classif="rollback"; reasons=["IMAGE_CLEANUP_ROLLBACK_IMAGE_PROTECTED"]
  else:
    for r in refs:
      rd=norm(r.get("digest") or "")
      if not rd: continue
      if rd==iid or iid.endswith(rd.replace("sha256:","")) or rd.endswith(iid.replace("sha256:","")) or rd in iid or iid in rd:
        src=r.get("source")
        mapping={
          "running_container":("used_by_running_container","IMAGE_CLEANUP_IMAGE_IN_USE"),
          "stopped_container":("used_by_stopped_container","IMAGE_CLEANUP_STOPPED_CONTAINER_REFERENCE"),
          "production_inventory":("used_by_other_production","IMAGE_CLEANUP_PRODUCTION_REFERENCE"),
          "stage_inventory":("used_by_stage","IMAGE_CLEANUP_STAGE_REFERENCE"),
          "candidate":("used_by_candidate","IMAGE_CLEANUP_CANDIDATE_REFERENCE"),
          "rollback_manifest":("rollback","IMAGE_CLEANUP_ROLLBACK_IMAGE_PROTECTED"),
          "active_operation":("protected_by_active_operation","IMAGE_CLEANUP_ACTIVE_OPERATION_REFERENCE"),
          "recovery":("protected_by_recovery","IMAGE_CLEANUP_RECOVERY_REFERENCE"),
        }
        if src in mapping and classif=="eligible_for_cleanup":
          classif, code = mapping[src]
          reasons=[code]
          break
  out.append({"image_id":iid,"classification":classif,"reasons":reasons,"release_id":img.get("release_id"),"labels":labels})
print(json.dumps({"images":out,"current_digest":cur,"rollback_digest":rb},separators=(",",":")))
PY
}
