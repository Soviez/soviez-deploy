# shellcheck shell=bash

soviez_migration_refuse_wildcard() {
  local target="$1"
  case "$target" in ""|"all"|"*"|"."|"..") return 0 ;; esac
  [[ "$target" == *"*"* || "$target" == *"?"* ]] && return 0
  return 1
}

soviez_migration_resolve_production() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    soviez_migration_die MIGRATION_SOURCE_REQUIRED "Exact Production environment ID required"
  fi
  if soviez_migration_refuse_wildcard "$target"; then
    soviez_migration_die MIGRATION_SOURCE_INVALID "Wildcard/all/implicit targeting is refused"
  fi
  # Stage denial
  if declare -F soviez_backup_is_stage_id >/dev/null 2>&1; then
    if soviez_backup_is_stage_id "$target"; then
      soviez_migration_die MIGRATION_SOURCE_INVALID "Stage targets cannot use Production discovery"
    fi
  elif [[ -d "${SOVIEZ_STAGES_DIR:-}/$target" ]]; then
    soviez_migration_die MIGRATION_SOURCE_INVALID "Stage targets cannot use Production discovery"
  fi

  if [[ -n "${SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON:-}" ]]; then
    local ft
    ft="$(soviez_json_get "$SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON" tenant_id 2>/dev/null || true)"
    [[ -z "$ft" ]] && ft="$(soviez_json_get "$SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON" environment_id 2>/dev/null || true)"
    if [[ "$ft" == "$target" ]]; then
      printf '%s' "$SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON"
      return 0
    fi
    # Multi-tenant fixtures: do not hard-fail yet; fall through to inventory/discovery cache.
  fi

  # Persisted production inventory (written by discovery; enables multi-tenant resolve)
  local inv="${SOVIEZ_MIG_ROOT:-}/productions/${target}/identity.json"
  if [[ -f "$inv" ]]; then
    cat "$inv"
    return 0
  fi

  # Latest discovery production.json for this environment
  if [[ -d "${SOVIEZ_MIG_DISCOVERY_DIR:-}" ]]; then
    local found=""
    found="$(SOVIEZ_T="$target" SOVIEZ_D="$SOVIEZ_MIG_DISCOVERY_DIR" python3 - <<'PY' 2>/dev/null || true
import json, os, pathlib
t = os.environ["SOVIEZ_T"]
root = pathlib.Path(os.environ["SOVIEZ_D"])
best = None
best_mtime = -1.0
for p in root.glob("*/production.json"):
    try:
        d = json.loads(p.read_text())
    except Exception:
        continue
    tid = d.get("tenant_id") or d.get("environment_id") or ""
    if tid != t:
        continue
    m = p.stat().st_mtime
    if m >= best_mtime:
        best_mtime = m
        best = d
if best is not None:
    print(json.dumps(best, separators=(",", ":")))
PY
)"
    if [[ -n "$found" ]]; then
      printf '%s' "$found"
      return 0
    fi
  fi

  if [[ -n "${SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON:-}" ]]; then
    soviez_migration_die MIGRATION_SOURCE_INVALID "Unknown Production: $target"
  fi

  if declare -F soviez_backup_resolve_production >/dev/null 2>&1; then
    soviez_backup_resolve_production "$target"
    return $?
  fi

  if declare -F soviez_update_resolve_target >/dev/null 2>&1; then
    soviez_update_resolve_target "$target"
    return $?
  fi

  local idf="${SOVIEZ_TENANT_DIR:-}/$target/identity.json"
  [[ -f "$idf" ]] || idf="${SOVIEZ_TENANT_DIR:-}/identity.json"
  [[ -f "$idf" ]] || soviez_migration_die MIGRATION_SOURCE_INVALID "Unknown Production: $target"
  SOVIEZ_ID="$(cat "$idf")" SOVIEZ_T="$target" python3 - <<'PY'
import json, os
d = json.loads(os.environ["SOVIEZ_ID"])
d["tenant_id"] = d.get("tenant_id") or os.environ["SOVIEZ_T"]
d["environment_id"] = d.get("environment_id") or d["tenant_id"]
print(json.dumps(d, separators=(",", ":")))
PY
}
