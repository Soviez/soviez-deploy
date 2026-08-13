# shellcheck shell=bash

soviez_ops_migrate_from_state() {
  local op_id="$1" state_file="$2" op_type="${3:-new}" op_dir canonical legacy_canonical legacy state record
  op_dir="$(soviez_operation_dir "$op_id")"
  mkdir -p "$op_dir"
  canonical="$op_dir/$SOVIEZ_OPS_CANONICAL_NAME"
  # Idempotent: already migrated into unified home (refresh if legacy checkpoint advanced)
  if [[ -f "$canonical" ]]; then
    local existing legacy_state canon_cp
    existing="$(cat "$canonical")"
    legacy_state="$(soviez_json_get "$(cat "$state_file")" state 2>/dev/null || true)"
    canon_cp="$(soviez_json_get "$existing" current_checkpoint 2>/dev/null || true)"
    if [[ -z "$legacy_state" || "$legacy_state" == "$canon_cp" || "$legacy_state" == "$(soviez_json_get "$existing" current_state)" ]]; then
      soviez_ops_validate_record "$existing"
      soviez_ops_registry_register "$op_id" 2>/dev/null || true
      return 0
    fi
    # Fall through to remap from advanced legacy state (preserve identity)
  fi
  # Also accept prior sidecar next to legacy (pre-unify)
  legacy_canonical="$(dirname "$state_file")/$SOVIEZ_OPS_CANONICAL_NAME"
  if [[ -f "$legacy_canonical" && "$(dirname "$state_file")" != "$op_dir" ]]; then
    cp "$legacy_canonical" "$canonical"
    chmod 600 "$canonical"
    soviez_ops_registry_register "$op_id"
    return 0
  fi
  legacy="$(cat "$state_file")" || soviez_ops_die OPERATION_STATE_CORRUPT "Missing legacy state"
  state="$(soviez_json_get "$legacy" state 2>/dev/null || printf 'recovery_required')"
  record="$(soviez_ops_new_record "$op_id" "$op_type" "$(soviez_json_get "$legacy" environment_id 2>/dev/null || true)" "$state")"
  record="$(SOVIEZ_REC="$record" SOVIEZ_STATE="$state" SOVIEZ_LEGACY="$state_file" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_REC"]); s=os.environ["SOVIEZ_STATE"] or "created"
shared={"created","queued","starting","running","waiting","retry_scheduled","cancel_requested","canceling","rollback_running","recovery_required","completed","canceled","failed_retryable","failed_terminal"}
if s in ("completed","canceled","failed_terminal","failed_retryable","recovery_required"):
    d["current_state"]=s
elif s in shared:
    d["current_state"]=s
else:
    waiting_like={"waiting_for_dns","waiting_for_connection_consent","waiting_for_activation_method","manual_activation_pending","device_authorization_pending","waiting_for_dns_propagation","ssl.waiting_for_dns","retention.waiting"}
    d["current_state"]="waiting" if s in waiting_like or s.startswith("waiting") else "running"
d["current_checkpoint"]=s
d["migrated_from_schema"]="legacy"
d["migration_timestamp"]=d.get("updated_at")
d["meta"]=d.get("meta") if isinstance(d.get("meta"), dict) else {}
d["meta"]["legacy_state_path"]=os.environ["SOVIEZ_LEGACY"]
print(json.dumps(d,separators=(",",":")))
PY
)"
  [[ -f "$state_file.pre-phase14.bak" ]] || cp "$state_file" "$state_file.pre-phase14.bak"
  soviez_stage_inventory_atomic_write "$canonical" "$record"
  # Keep a sidecar next to legacy when the legacy root differs (Stage/SSL/retention).
  if [[ "$(dirname "$state_file")" != "$op_dir" ]]; then
    soviez_stage_inventory_atomic_write "$legacy_canonical" "$record" 2>/dev/null || true
  fi
  soviez_ops_registry_register "$op_id"
}

soviez_ops_migrate_legacy_new() { soviez_ops_migrate_from_state "$1" "$(soviez_operation_state_file "$1")" new; }
soviez_ops_migrate_legacy_stage() { soviez_ops_migrate_from_state "$1" "$(soviez_stage_op_state_file "$1")" stage_create; }
soviez_ops_migrate_legacy_ssl() { local f="$SOVIEZ_SSL_OPS_DIR/$1/state.json"; soviez_ops_migrate_from_state "$1" "$f" ssl_renewal; }
soviez_ops_migrate_legacy_retention() {
  local f id
  f="$(soviez_retention_file "$1")"
  id="$(soviez_json_get "$(cat "$f")" retention_operation_id)"
  [[ -n "$id" ]] || soviez_ops_die OPERATION_MIGRATION_FAILED "retention_operation_id missing"
  soviez_ops_migrate_from_state "$id" "$f" retention_delete
}

soviez_ops_migrate_one() {
  local value="$1" dir state
  dir="$value"; [[ -d "$dir" ]] || dir="$(soviez_ops_resolve_dir "$value")"
  state="$dir/state.json"
  if [[ ! -f "$state" ]]; then
    # Retention inventory path may be passed as environment id
    if declare -F soviez_retention_file >/dev/null 2>&1 && [[ -f "$(soviez_retention_file "$value" 2>/dev/null || true)" ]]; then
      soviez_ops_migrate_legacy_retention "$value"
      return 0
    fi
    soviez_ops_die OPERATION_NOT_FOUND "No legacy operation: $value"
  fi
  soviez_ops_migrate_from_state "$(soviez_json_get "$(cat "$state")" operation_id 2>/dev/null || basename "$dir")" "$state" "$(
    kind="$(soviez_json_get "$(cat "$state")" kind 2>/dev/null || echo new)"
    case "$kind" in stage) printf 'stage_create' ;; ssl*) printf 'ssl_renewal' ;; retention*) printf 'retention_delete' ;; *) printf '%s' "$kind" ;; esac
  )"
}

soviez_ops_migrate_all() {
  local dry="${1:-}" d
  for d in "$SOVIEZ_OPS_ROOT/operations"/* "$SOVIEZ_STAGE_OPS_DIR"/* "$SOVIEZ_SSL_OPS_DIR"/*; do
    [[ -d "$d" && -f "$d/state.json" ]] || continue
    if [[ "$dry" == --dry-run ]]; then printf '%s\n' "$d"; continue; fi
    soviez_ops_migrate_one "$d"
  done
}
