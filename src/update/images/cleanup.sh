# shellcheck shell=bash

soviez_image_cleanup_paths_init() {
  soviez_update_paths_init 2>/dev/null || true
  SOVIEZ_IMAGE_CLEANUP_DIR="${SOVIEZ_IMAGE_CLEANUP_DIR:-$SOVIEZ_UPDATE_ROOT/image_cleanup}"
  mkdir -p "$SOVIEZ_IMAGE_CLEANUP_DIR/history" "$SOVIEZ_IMAGE_CLEANUP_DIR/operations"
  export SOVIEZ_IMAGE_CLEANUP_DIR
}

soviez_image_resolve_current_rollback() {
  local production_id="${1:-}"
  local tenant_dir="${SOVIEZ_TENANT_DIR:-$SOVIEZ_ROOT/tenant}"
  local idf=""
  if [[ -n "$production_id" && -f "$tenant_dir/$production_id/identity.json" ]]; then
    idf="$tenant_dir/$production_id/identity.json"
  elif [[ -f "$tenant_dir/identity.json" ]]; then
    idf="$tenant_dir/identity.json"
  fi
  if [[ -z "$idf" ]]; then
    # Fallback: latest completed update op
    local latest
    latest="$(ls -1t "$SOVIEZ_UPDATE_OPS_DIR"/*/switch.json 2>/dev/null | head -1 || true)"
    if [[ -n "$latest" ]]; then
      SOVIEZ_S="$(cat "$latest")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_S"])
print(json.dumps({"current_digest":d.get("current_digest"),"rollback_digest":d.get("previous_digest"),"source":"switch.json"},separators=(",",":")))
PY
      return 0
    fi
    printf '{"current_digest":null,"rollback_digest":null}\n'
    return 0
  fi
  SOVIEZ_ID="$(cat "$idf")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
print(json.dumps({
  "current_digest":d.get("current_digest") or d.get("image_digest"),
  "rollback_digest":d.get("previous_digest") or d.get("rollback_digest"),
  "production_id":d.get("tenant_id"),
  "source":"identity.json",
},separators=(",",":")))
PY
}

soviez_image_safety_window_elapsed() {
  local op_id="${1:-}"
  local man hours
  if [[ -n "$op_id" && -f "$(soviez_update_rollback_manifest "$op_id")" ]]; then
    man="$(cat "$(soviez_update_rollback_manifest "$op_id")")"
  else
    return 1
  fi
  hours="${SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS:-24}"
  SOVIEZ_M="$man" SOVIEZ_H="$hours" SOVIEZ_FORCE="${SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED:-0}" python3 - <<'PY'
import json,os,sys
from datetime import datetime,timedelta,timezone
if os.environ.get("SOVIEZ_FORCE")=="1":
  sys.exit(0)
m=json.loads(os.environ["SOVIEZ_M"])
created=m.get("created_at") or ""
try:
  dt=datetime.fromisoformat(created.replace("Z","+00:00"))
except Exception:
  sys.exit(1)
hours=int(os.environ["SOVIEZ_H"])
sys.exit(0 if datetime.now(timezone.utc) >= dt+timedelta(hours=hours) else 1)
PY
}

soviez_image_cleanup_dry_run() {
  local production_id="${1:-}"
  soviez_image_cleanup_paths_init
  soviez_image_forbid_prune_static_gate >/dev/null
  local pair refs classified
  pair="$(soviez_image_resolve_current_rollback "$production_id")"
  local cur rb
  cur="$(soviez_json_get "$pair" current_digest 2>/dev/null || true)"
  rb="$(soviez_json_get "$pair" rollback_digest 2>/dev/null || true)"
  refs="$(soviez_image_collect_references)"
  classified="$(soviez_image_classify "$cur" "$rb" "$refs")"
  SOVIEZ_C="$classified" SOVIEZ_P="$pair" python3 - <<'PY'
import json,os
c=json.loads(os.environ["SOVIEZ_C"])
p=json.loads(os.environ["SOVIEZ_P"])
eligible=[i for i in c.get("images",[]) if i.get("classification")=="eligible_for_cleanup"]
protected=[i for i in c.get("images",[]) if i.get("classification")!="eligible_for_cleanup"]
print(json.dumps({
  "ok":True,"dry_run":True,"code":"IMAGE_CLEANUP_DRY_RUN",
  "current_digest":p.get("current_digest"),"rollback_digest":p.get("rollback_digest"),
  "eligible":eligible,"protected":protected,
  "would_delete_count":len(eligible),"protected_count":len(protected),
},separators=(",",":")))
PY
}

soviez_image_cleanup_execute() {
  local production_id="${1:-}" confirm="${2:-0}" op_id="${3:-}" dry_run="${4:-0}"
  soviez_image_cleanup_paths_init
  soviez_image_forbid_prune_static_gate >/dev/null

  if [[ "$dry_run" == "1" ]]; then
    soviez_image_cleanup_dry_run "$production_id"
    return 0
  fi
  if [[ ! -t 0 && "$confirm" != "1" && "${SOVIEZ_CLI_CONFIRM:-0}" != "1" ]]; then
    soviez_image_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Image cleanup requires --confirm in non-TTY"
  fi
  [[ "$confirm" == "1" || "${SOVIEZ_CLI_CONFIRM:-0}" == "1" || -t 0 ]] \
    || soviez_image_die DESTRUCTIVE_CONFIRMATION_REQUIRED "Image cleanup requires confirmation"

  if [[ -n "$op_id" ]]; then
    if ! soviez_image_safety_window_elapsed "$op_id"; then
      soviez_image_die IMAGE_CLEANUP_SAFETY_WINDOW_ACTIVE "24h rollback safety window still active"
    fi
  fi

  local before_df pair refs classified
  before_df="$(soviez_image_usage_report)"
  pair="$(soviez_image_resolve_current_rollback "$production_id")"
  local cur rb
  cur="$(soviez_json_get "$pair" current_digest)"
  rb="$(soviez_json_get "$pair" rollback_digest)"
  [[ -n "$cur" && "$cur" != "null" ]] || soviez_image_die IMAGE_CLEANUP_NEEDS_ACTION "Current digest unknown"

  local deleted=() failed=() protected_count=0
  local reclaim_est=0 reclaim_actual=0

  # Loop with TOCTOU revalidation immediately before each delete
  while true; do
    refs="$(soviez_image_collect_references)"
    classified="$(soviez_image_classify "$cur" "$rb" "$refs")"
    local target
    target="$(SOVIEZ_C="$classified" python3 - <<'PY'
import json,os
c=json.loads(os.environ["SOVIEZ_C"])
for i in c.get("images",[]):
  if i.get("classification")=="eligible_for_cleanup":
    print(i.get("image_id") or ""); break
PY
)"
    [[ -n "$target" ]] || break

    # TOCTOU revalidate
    refs="$(soviez_image_collect_references)"
    classified="$(soviez_image_classify "$cur" "$rb" "$refs")"
    local still
    still="$(SOVIEZ_C="$classified" SOVIEZ_T="$target" python3 - <<'PY'
import json,os
c=json.loads(os.environ["SOVIEZ_C"]); t=os.environ["SOVIEZ_T"]
for i in c.get("images",[]):
  if (i.get("image_id") or "")==t and i.get("classification")=="eligible_for_cleanup":
    print("yes"); break
else:
  print("no")
PY
)"
    if [[ "$still" != "yes" ]]; then
      protected_count=$((protected_count+1))
      continue
    fi

    local size_json
    size_json="$(soviez_image_inspect_sizes "$target")"
    local logical
    logical="$(soviez_json_get "$size_json" logical_size_bytes 2>/dev/null || echo 0)"
    reclaim_est=$((reclaim_est + logical))

    if [[ "${SOVIEZ_IMAGE_CLEANUP_INJECT_DELETE_FAIL:-0}" == "1" ]]; then
      failed+=("$target")
      unset SOVIEZ_IMAGE_CLEANUP_INJECT_DELETE_FAIL
      continue
    fi

    if soviez_image_docker rmi "$target" >/dev/null 2>&1; then
      deleted+=("$target")
      reclaim_actual=$((reclaim_actual + logical))  # upper bound; honest note in report
    else
      failed+=("$target")
    fi
  done

  local after_df
  after_df="$(soviez_image_usage_report)"
  local hist="$SOVIEZ_IMAGE_CLEANUP_DIR/history/cleanup-$(date +%Y%m%d%H%M%S).json"
  local del_csv="" fail_csv=""
  if [[ ${#deleted[@]} -gt 0 ]]; then del_csv="$(IFS=,; echo "${deleted[*]}")"; fi
  if [[ ${#failed[@]} -gt 0 ]]; then fail_csv="$(IFS=,; echo "${failed[*]}")"; fi
  SOVIEZ_DEL="$del_csv" SOVIEZ_FAIL="$fail_csv" \
  SOVIEZ_EST="$reclaim_est" SOVIEZ_ACT="$reclaim_actual" SOVIEZ_B="$before_df" SOVIEZ_A="$after_df" \
  SOVIEZ_CUR="$cur" SOVIEZ_RB="$rb" python3 - <<'PY' > "$hist"
import json,os
deleted=[x for x in (os.environ.get("SOVIEZ_DEL") or "").split(",") if x]
failed=[x for x in (os.environ.get("SOVIEZ_FAIL") or "").split(",") if x]
code="IMAGE_CLEANUP_COMPLETED"
if failed and deleted: code="IMAGE_CLEANUP_PARTIAL"
elif failed and not deleted: code="IMAGE_CLEANUP_NEEDS_ACTION"
print(json.dumps({
  "ok": code in ("IMAGE_CLEANUP_COMPLETED","IMAGE_CLEANUP_PARTIAL"),
  "code": code,
  "current_digest": os.environ.get("SOVIEZ_CUR"),
  "rollback_digest": os.environ.get("SOVIEZ_RB"),
  "deleted": deleted,
  "failed": failed,
  "estimated_reclaimable_bytes": int(os.environ.get("SOVIEZ_EST") or 0),
  "reported_reclaimed_bytes_upper_bound": int(os.environ.get("SOVIEZ_ACT") or 0),
  "shared_layer_note": "Actual free space may be less than logical sum due to shared layers",
  "docker_df_before": json.loads(os.environ.get("SOVIEZ_B") or "{}"),
  "docker_df_after": json.loads(os.environ.get("SOVIEZ_A") or "{}"),
  "erp_update_success_unaffected": True,
},separators=(",",":")))
PY
  cat "$hist"
  if [[ ${#failed[@]} -gt 0 && ${#deleted[@]} -eq 0 ]]; then
    return 1
  fi
}

soviez_image_status() {
  local production_id="${1:-}"
  soviez_image_cleanup_dry_run "$production_id"
}
