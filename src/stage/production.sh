# shellcheck shell=bash
# Enumerate locally managed Production tenants (safe metadata only).

soviez_stage_list_productions() {
  # Discovers identity.json files under SOVIEZ_TENANT_DIR and optional multi-tenant layout.
  local root="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}"
  python3 - "$root" "$SOVIEZ_STAGES_DIR" <<'PY'
import json, os, sys, glob
root, stages_dir = sys.argv[1], sys.argv[2]
cands=[]
paths=glob.glob(os.path.join(root, "**/identity.json"), recursive=True)
if os.path.isfile(os.path.join(root, "identity.json")):
    paths.append(os.path.join(root, "identity.json"))
seen=set()
for p in paths:
    try:
        data=json.load(open(p))
    except Exception:
        continue
    tid=data.get("tenant_id") or data.get("id")
    if not tid or tid in seen: continue
    seen.add(tid)
    stage_count=0
    idx=os.path.join(stages_dir, "index.json")
    if os.path.isfile(idx):
        try:
            for s in json.load(open(idx)).get("stages",[]):
                if s.get("parent_production_tenant_id")==tid or True:
                    # Count stages whose identity parent matches when present
                    idp=os.path.join(stages_dir, s.get("stage_id",""), "identity.json")
                    if os.path.isfile(idp):
                        try:
                            sid=json.load(open(idp))
                            if sid.get("parent_production_tenant_id")==tid:
                                stage_count+=1
                        except Exception:
                            pass
        except Exception:
            pass
    cands.append({
        "tenant_id": tid,
        "domain": data.get("domain") or data.get("public_domain"),
        "license_id": data.get("license_id"),
        "release_version": data.get("release_version") or data.get("digest"),
        "database_name": data.get("db_name") or data.get("database_name"),
        "database_uuid": data.get("database_uuid"),
        "production_fingerprint": data.get("fingerprint") or data.get("production_fingerprint"),
        "container": data.get("container") or data.get("web_container"),
        "container_status": data.get("container_status") or "unknown",
        "stage_count": stage_count,
        "identity_path": p,
        "entitlement_checkable": bool(data.get("license_id")),
    })
print(json.dumps({"productions": cands}, separators=(",", ":")))
PY
}

soviez_stage_select_production() {
  local forced_tenant="${1:-${SOVIEZ_CLI_PRODUCTION_TENANT:-}}"
  local listing
  listing="$(soviez_stage_list_productions)"
  local count
  count="$(SOVIEZ_L="$listing" python3 - <<'PY'
import json,os
print(len(json.loads(os.environ["SOVIEZ_L"]).get("productions",[])))
PY
)"
  if [[ "$count" -eq 0 ]]; then
    # Test/fixture fallback: allow explicit env fixture.
    if [[ -n "${SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON:-}" ]]; then
      printf '%s' "$SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON"
      return 0
    fi
    soviez_stage_die NO_MANAGED_PRODUCTION "No locally managed Production instances found"
  fi

  if [[ -n "$forced_tenant" ]]; then
    SOVIEZ_L="$listing" SOVIEZ_T="$forced_tenant" python3 - <<'PY'
import json,os,sys
prods=json.loads(os.environ["SOVIEZ_L"])["productions"]
for p in prods:
    if p.get("tenant_id")==os.environ["SOVIEZ_T"]:
        print(json.dumps(p, separators=(",",":"))); sys.exit(0)
sys.exit(2)
PY
    local rc=$?
    [[ $rc -eq 0 ]] || soviez_stage_die PRODUCTION_SELECTION_REQUIRED "Unknown Production tenant: $forced_tenant"
    return 0
  fi

  if [[ "$count" -eq 1 ]]; then
    SOVIEZ_L="$listing" python3 - <<'PY'
import json,os
print(json.dumps(json.loads(os.environ["SOVIEZ_L"])["productions"][0], separators=(",",":")))
PY
    return 0
  fi

  if [[ ! -t 0 ]]; then
    soviez_stage_die PRODUCTION_SELECTION_REQUIRED "Multiple Productions; pass --production-tenant <id>"
  fi

  echo "Select Production:" >&2
  SOVIEZ_L="$listing" python3 - <<'PY' >&2
import json,os
for i,p in enumerate(json.loads(os.environ["SOVIEZ_L"])["productions"],1):
    print(f"{i}) tenant={p.get('tenant_id')} domain={p.get('domain')} license={p.get('license_id')} stages={p.get('stage_count')}")
PY
  printf 'Enter number: ' >&2
  local n
  read -r n
  SOVIEZ_L="$listing" SOVIEZ_N="$n" python3 - <<'PY'
import json,os,sys
prods=json.loads(os.environ["SOVIEZ_L"])["productions"]
i=int(os.environ["SOVIEZ_N"])-1
if i<0 or i>=len(prods):
    sys.exit(2)
print(json.dumps(prods[i], separators=(",",":")))
PY
  [[ $? -eq 0 ]] || soviez_stage_die PRODUCTION_SELECTION_REQUIRED "Invalid selection"
}

soviez_stage_validate_production() {
  local prod_json="$1"
  local license_id fingerprint db_uuid
  license_id="$(soviez_json_get "$prod_json" license_id 2>/dev/null || true)"
  fingerprint="$(soviez_json_get "$prod_json" production_fingerprint 2>/dev/null || true)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid 2>/dev/null || true)"
  [[ -n "$license_id" ]] || soviez_stage_die LICENSE_BINDING_MISSING "Production missing license_id"
  [[ -n "$fingerprint" ]] || soviez_stage_die PRODUCTION_IDENTITY_MISMATCH "Production missing fingerprint"
  [[ -n "$db_uuid" ]] || soviez_stage_die PRODUCTION_IDENTITY_MISMATCH "Production missing database_uuid"
  local status
  status="$(soviez_json_get "$prod_json" container_status 2>/dev/null || echo unknown)"
  if [[ "$status" == "unhealthy" || "$status" == "exited" ]]; then
    soviez_stage_die PRODUCTION_UNHEALTHY "Production container status=$status"
  fi
}
