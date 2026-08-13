# shellcheck shell=bash

soviez_backup_refuse_wildcard() {
  local target="$1"
  case "$target" in
    ""|"all"|"*"|"."|"..") return 0 ;;
  esac
  [[ "$target" == *"*"* || "$target" == *"?"* ]] && return 0
  return 1
}

soviez_backup_is_stage_id() {
  local target="$1"
  if declare -F soviez_stage_inventory_find >/dev/null 2>&1; then
    soviez_stage_inventory_find "$target" >/dev/null 2>&1 && return 0
  fi
  [[ -d "${SOVIEZ_STAGES_DIR:-}/$target" ]] && return 0
  return 1
}

soviez_backup_resolve_production() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    soviez_backup_die BACKUP_TARGET_REQUIRED "Exact Production environment ID required"
  fi
  if soviez_backup_refuse_wildcard "$target"; then
    soviez_backup_die BACKUP_TARGET_INVALID "Wildcard/all/implicit targeting is refused"
  fi
  if soviez_backup_is_stage_id "$target"; then
    soviez_backup_die BACKUP_STAGE_TARGET_DENIED "Stage targets cannot use Production backup"
  fi

  # Prefer shared update resolver when available
  if declare -F soviez_update_resolve_target >/dev/null 2>&1; then
    local prod
    prod="$(soviez_update_resolve_target "$target" 2>/dev/null)" || {
      # Map update codes to backup codes when possible
      if declare -F soviez_stage_list_productions >/dev/null 2>&1; then
        :
      else
        soviez_backup_die BACKUP_TARGET_INVALID "Unknown Production: $target"
      fi
    }
    if [[ -n "${prod:-}" ]]; then
      printf '%s' "$prod"
      return 0
    fi
  fi

  local listing prod
  if ! declare -F soviez_stage_list_productions >/dev/null 2>&1; then
    # Fixture / tenant identity fallback
    if [[ -n "${SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON:-}" ]]; then
      local ft
      ft="$(soviez_json_get "$SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON" tenant_id 2>/dev/null || true)"
      [[ "$ft" == "$target" ]] || soviez_backup_die BACKUP_TARGET_INVALID "Unknown Production: $target"
      printf '%s' "$SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON"
      return 0
    fi
    local idf="${SOVIEZ_TENANT_DIR:-}/$target/identity.json"
    [[ -f "$idf" ]] || idf="${SOVIEZ_TENANT_DIR:-}/identity.json"
    [[ -f "$idf" ]] || soviez_backup_die BACKUP_TARGET_INVALID "Unknown Production: $target"
    SOVIEZ_ID="$(cat "$idf")" SOVIEZ_T="$target" python3 - <<'PY'
import json, os
d = json.loads(os.environ["SOVIEZ_ID"])
d["tenant_id"] = d.get("tenant_id") or os.environ["SOVIEZ_T"]
d["environment_id"] = d.get("environment_id") or d["tenant_id"]
print(json.dumps(d, separators=(",", ":")))
PY
    return 0
  fi

  listing="$(soviez_stage_list_productions)"
  prod="$(SOVIEZ_L="$listing" SOVIEZ_T="$target" python3 - <<'PY'
import json, os, sys
prods = json.loads(os.environ["SOVIEZ_L"]).get("productions", [])
matches = [p for p in prods if p.get("tenant_id") == os.environ["SOVIEZ_T"]
           or p.get("environment_id") == os.environ["SOVIEZ_T"]]
if len(matches) == 0:
    sys.exit(3)
if len(matches) > 1:
    sys.exit(2)
print(json.dumps(matches[0], separators=(",", ":")))
PY
)" || {
    local rc=$?
    case "$rc" in
      2) soviez_backup_die BACKUP_TARGET_AMBIGUOUS "Multiple Productions match: $target" ;;
      3)
        if [[ -n "${SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON:-}" ]]; then
          local ft
          ft="$(soviez_json_get "$SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON" tenant_id 2>/dev/null || true)"
          [[ "$ft" == "$target" ]] || soviez_backup_die BACKUP_TARGET_INVALID "Unknown Production: $target"
          printf '%s' "$SOVIEZ_BACKUP_FIXTURE_PRODUCTION_JSON"
          return 0
        fi
        local idf="${SOVIEZ_TENANT_DIR:-}/$target/identity.json"
        [[ -f "$idf" ]] || soviez_backup_die BACKUP_TARGET_INVALID "Unknown Production: $target"
        SOVIEZ_ID="$(cat "$idf")" SOVIEZ_T="$target" python3 - <<'PY'
import json, os
d = json.loads(os.environ["SOVIEZ_ID"])
d["tenant_id"] = d.get("tenant_id") or os.environ["SOVIEZ_T"]
d["environment_id"] = d.get("environment_id") or d["tenant_id"]
print(json.dumps(d, separators=(",", ":")))
PY
        return 0
        ;;
      *) soviez_backup_die BACKUP_TARGET_INVALID "Failed to resolve Production: $target" ;;
    esac
  }
  printf '%s' "$prod"
}

soviez_backup_verify_production_identity() {
  local prod_json="$1"
  local license_id db_uuid fingerprint host_now expected_host
  license_id="$(soviez_json_get "$prod_json" license_id 2>/dev/null || true)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid 2>/dev/null || true)"
  fingerprint="$(soviez_json_get "$prod_json" production_fingerprint 2>/dev/null \
    || soviez_json_get "$prod_json" fingerprint 2>/dev/null || true)"
  [[ -n "$license_id" && "$license_id" != "null" ]] \
    || soviez_backup_die BACKUP_PRODUCTION_IDENTITY_MISMATCH "Production missing license_id"
  [[ -n "$db_uuid" && "$db_uuid" != "null" ]] \
    || soviez_backup_die BACKUP_PRODUCTION_IDENTITY_MISMATCH "Production missing database_uuid"
  [[ -n "$fingerprint" && "$fingerprint" != "null" ]] \
    || soviez_backup_die BACKUP_PRODUCTION_IDENTITY_MISMATCH "Production missing fingerprint"
  host_now="$(hostname -f 2>/dev/null || hostname || echo unknown)"
  expected_host="$(soviez_json_get "$prod_json" host_identity 2>/dev/null || true)"
  if [[ -n "$expected_host" && "$expected_host" != "null" && "$expected_host" != "unknown" ]]; then
    [[ "$expected_host" == "$host_now" || "$expected_host" == "$(hostname 2>/dev/null || true)" ]] \
      || soviez_backup_die BACKUP_HOST_IDENTITY_MISMATCH "Host identity mismatch"
  fi
  printf '%s' "$prod_json"
}
