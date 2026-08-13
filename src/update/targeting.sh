# shellcheck shell=bash

soviez_update_refuse_wildcard() {
  local target="$1"
  case "$target" in
    ""|"all"|"*"|"."|"..")
      return 0
      ;;
  esac
  [[ "$target" == *"*"* || "$target" == *"?"* ]] && return 0
  return 1
}

soviez_update_is_stage_id() {
  local target="$1"
  if declare -F soviez_stage_inventory_find >/dev/null 2>&1; then
    soviez_stage_inventory_find "$target" >/dev/null 2>&1 && return 0
  fi
  [[ -d "${SOVIEZ_STAGES_DIR:-}/$target" ]] && return 0
  return 1
}

soviez_update_resolve_target() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    soviez_update_die UPDATE_TARGET_REQUIRED "Exact Production environment ID required"
  fi
  if soviez_update_refuse_wildcard "$target"; then
    soviez_update_die UPDATE_TARGET_INVALID "Wildcard/all/implicit targeting is refused"
  fi
  if soviez_update_is_stage_id "$target"; then
    soviez_update_die UPDATE_STAGE_TARGET_DENIED "Stage targets cannot be updated with --update"
  fi

  local listing prod
  listing="$(soviez_stage_list_productions)"
  prod="$(SOVIEZ_L="$listing" SOVIEZ_T="$target" python3 - <<'PY'
import json, os, sys
prods=json.loads(os.environ["SOVIEZ_L"]).get("productions",[])
matches=[p for p in prods if p.get("tenant_id")==os.environ["SOVIEZ_T"] or p.get("environment_id")==os.environ["SOVIEZ_T"]]
if len(matches)==0:
    # Allow explicit fixture identity path under tenant dir
    sys.exit(3)
if len(matches)>1:
    sys.exit(2)
print(json.dumps(matches[0], separators=(",",":")))
PY
)" || {
    local rc=$?
    case "$rc" in
      2) soviez_update_die UPDATE_TARGET_AMBIGUOUS "Multiple Productions match: $target" ;;
      3)
        if [[ -n "${SOVIEZ_UPDATE_FIXTURE_PRODUCTION_JSON:-}" ]]; then
          local ft
          ft="$(soviez_json_get "$SOVIEZ_UPDATE_FIXTURE_PRODUCTION_JSON" tenant_id 2>/dev/null || true)"
          [[ "$ft" == "$target" ]] || soviez_update_die UPDATE_TARGET_INVALID "Unknown Production: $target"
          printf '%s' "$SOVIEZ_UPDATE_FIXTURE_PRODUCTION_JSON"
          return 0
        fi
        # Load from tenant identity if path exists
        local idf="${SOVIEZ_TENANT_DIR:-}/$target/identity.json"
        [[ -f "$idf" ]] || idf="${SOVIEZ_TENANT_DIR:-}/identity.json"
        if [[ -f "$idf" ]]; then
          local loaded tid
          loaded="$(cat "$idf")"
          tid="$(soviez_json_get "$loaded" tenant_id 2>/dev/null || true)"
          [[ "$tid" == "$target" || "$(basename "$(dirname "$idf")")" == "$target" || "$(dirname "$idf")" == "${SOVIEZ_TENANT_DIR:-}" ]] \
            || soviez_update_die UPDATE_TARGET_INVALID "Unknown Production: $target"
          # Normalize
          SOVIEZ_ID="$loaded" SOVIEZ_T="$target" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
d["tenant_id"]=d.get("tenant_id") or os.environ["SOVIEZ_T"]
d["environment_id"]=d.get("environment_id") or d["tenant_id"]
print(json.dumps(d,separators=(",",":")))
PY
          return 0
        fi
        soviez_update_die UPDATE_TARGET_INVALID "Unknown Production: $target"
        ;;
      *) soviez_update_die UPDATE_TARGET_INVALID "Failed to resolve Production: $target" ;;
    esac
  }
  # Enrich from full identity.json when available
  local idp
  idp="$(soviez_json_get "$prod" identity_path 2>/dev/null || true)"
  if [[ -n "$idp" && -f "$idp" ]]; then
    prod="$(SOVIEZ_BASE="$prod" SOVIEZ_ID="$(cat "$idp")" python3 - <<'PY'
import json,os
base=json.loads(os.environ["SOVIEZ_BASE"])
full=json.loads(os.environ["SOVIEZ_ID"])
for k,v in full.items():
  if v is not None and (k not in base or base.get(k) in (None,"",[])):
    base[k]=v
  elif k in ("current_digest","image_digest","database_path","filestore_path","addons_path","account_id","erp_major","host_identity","nginx_config_ref","cert_ref","database_bytes","filestore_bytes","image_bytes"):
    base[k]=v
base["tenant_id"]=base.get("tenant_id") or full.get("tenant_id")
base["environment_id"]=base.get("environment_id") or base["tenant_id"]
print(json.dumps(base,separators=(",",":")))
PY
)"
  fi
  printf '%s' "$prod"
}

soviez_update_verify_identity() {
  local prod_json="$1" host_now
  local license_id db_uuid fingerprint container prod_status
  license_id="$(soviez_json_get "$prod_json" license_id 2>/dev/null || true)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid 2>/dev/null || true)"
  fingerprint="$(soviez_json_get "$prod_json" production_fingerprint 2>/dev/null || soviez_json_get "$prod_json" fingerprint 2>/dev/null || true)"
  container="$(soviez_json_get "$prod_json" container 2>/dev/null || true)"
  prod_status="$(soviez_json_get "$prod_json" container_status 2>/dev/null || echo unknown)"
  [[ -n "$license_id" && "$license_id" != "null" ]] || soviez_update_die UPDATE_LICENSE_BINDING_MISMATCH "Production missing license_id"
  [[ -n "$db_uuid" && "$db_uuid" != "null" ]] || soviez_update_die UPDATE_DATABASE_UUID_MISMATCH "Production missing database_uuid"
  [[ -n "$fingerprint" && "$fingerprint" != "null" ]] || soviez_update_die UPDATE_PRODUCTION_IDENTITY_MISMATCH "Production missing fingerprint"
  host_now="$(hostname -f 2>/dev/null || hostname || echo unknown)"
  local expected_host
  expected_host="$(soviez_json_get "$prod_json" host_identity 2>/dev/null || true)"
  if [[ -n "$expected_host" && "$expected_host" != "null" && "$expected_host" != "unknown" ]]; then
    [[ "$expected_host" == "$host_now" || "$expected_host" == "$(hostname 2>/dev/null || true)" ]] \
      || soviez_update_die UPDATE_HOST_IDENTITY_MISMATCH "Host identity mismatch"
  fi
  if [[ "$prod_status" == "deleted" || "$prod_status" == "archived" ]]; then
    soviez_update_die UPDATE_TARGET_INVALID "Production status is $prod_status"
  fi
  printf '%s' "$prod_json"
}
