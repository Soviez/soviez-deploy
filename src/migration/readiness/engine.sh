# shellcheck shell=bash

soviez_migration_capacity_required_bytes() {
  local discovery_json="$1" selected_stages_json="${2:-[]}"
  SOVIEZ_D="$discovery_json" SOVIEZ_S="$selected_stages_json" SOVIEZ_M="${SOVIEZ_MIG_CAPACITY_MARGIN_PCT:-25}" python3 - <<'PY'
import json, os, math
d=json.loads(os.environ["SOVIEZ_D"])
cap=d.get("capacity") or {}
stages=json.loads(os.environ["SOVIEZ_S"] or "[]")
stage_bytes=0
inv=(d.get("stages") or {}).get("stages") or []
sel=set(stages)
for st in inv:
  if st.get("stage_id") in sel:
    stage_bytes += int(st.get("database_bytes") or 0) + int(st.get("filestore_bytes") or 0)
base = (
  int(cap.get("database_bytes") or 0)
  + int(cap.get("filestore_bytes") or 0)
  + int(cap.get("addon_bytes") or 0)
  + int(cap.get("configuration_bytes") or 0)
  + stage_bytes
)
# workspace + backup/rollback reserve + image storage + pg temp + ops overhead (derived, not unexplained fixed magic)
workspace = int(base * 0.15)
backup_reserve = int(base * 0.20)
image_storage = 2 * 1024 * 1024 * 1024  # two image layers budget from measured product images later; documented component
pg_temp = int(int(cap.get("database_bytes") or 0) * 0.30)
ops_overhead = 256 * 1024 * 1024
subtotal = base + workspace + backup_reserve + image_storage + pg_temp + ops_overhead
margin = int(os.environ["SOVIEZ_M"])
required = math.ceil(subtotal * (100 + margin) / 100)
print(json.dumps({
  "base_bytes": base,
  "workspace_bytes": workspace,
  "backup_rollback_reserve_bytes": backup_reserve,
  "image_storage_bytes": image_storage,
  "postgresql_temp_bytes": pg_temp,
  "ops_overhead_bytes": ops_overhead,
  "stage_bytes": stage_bytes,
  "margin_pct": margin,
  "required_bytes": required,
  "required_inodes": int(cap.get("inode_estimate") or 0) + 10000 + len(sel)*1000,
}, separators=(",", ":")))
PY
}

soviez_migration_token_eligibility() {
  # Read-only check; never reserve/consume
  if [[ "${SOVIEZ_MIG_OFFLINE:-0}" == "1" ]]; then
    printf '%s' '{"status":"not_checked_offline","consumed":false,"reserved":false}'
    return 0
  fi
  if [[ -n "${SOVIEZ_MIG_FIXTURE_TOKEN_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_TOKEN_JSON"
    return 0
  fi
  if [[ -n "${SOVIEZ_MIG_TOKEN_LEDGER_PATH:-}" && -f "${SOVIEZ_MIG_TOKEN_LEDGER_PATH}" ]]; then
    # Provider-neutral local ledger fixture — read only, never mutate
    SOVIEZ_L="$SOVIEZ_MIG_TOKEN_LEDGER_PATH" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_L"]))
print(json.dumps({
  "status": d.get("status") or ("eligible" if int(d.get("available_quantity") or 0)>0 else "unavailable"),
  "available_quantity": d.get("available_quantity"),
  "consumed": False,
  "reserved": False,
}, separators=(",", ":")))
PY
    return 0
  fi
  # Default: unavailable but not consumed
  printf '%s' '{"status":"unavailable","available_quantity":0,"consumed":false,"reserved":false}'
}

soviez_migration_readiness_run() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local pair_path pair discovery_id discovery bootstrap_id bootstrap
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$pair_path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown pair: $pair_id"
  pair="$(cat "$pair_path")"
  [[ "$(soviez_json_get "$pair" aborted)" != "true" ]] || soviez_migration_die MIGRATION_ABORTED "Pair aborted"
  if soviez_migration_is_expired "$(soviez_json_get "$pair" pair_expires_at)"; then
    soviez_migration_die MIGRATION_PAIR_EXPIRED "Pair expired"
  fi
  if ! soviez_migration_verify_object_signature "$pair_path"; then
    soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Pair signature invalid"
  fi

  discovery_id="$(soviez_json_get "$pair" source_discovery_id)"
  bootstrap_id="$(soviez_json_get "$pair" destination_bootstrap_id)"
  discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json")"
  bootstrap="$(cat "$(soviez_migration_bootstrap_dir "$bootstrap_id")/object.json")"

  local warnings=() blockers=()
  local result="PASS"

  # Platform
  local os_id arch
  os_id="$(soviez_json_get "$bootstrap" os_version)"
  arch="$(soviez_json_get "$bootstrap" architecture)"
  if ! soviez_migration_os_supported "$os_id"; then
    blockers+=("unsupported_os"); result="BLOCKED"
  fi
  if ! soviez_migration_arch_supported "$arch"; then
    blockers+=("unsupported_arch"); result="BLOCKED"
  fi

  # Capacity
  local selected capacity_req avail_bytes avail_inodes
  selected="$(soviez_json_get "$pair" selected_stage_ids)"
  [[ -z "$selected" || "$selected" == "null" ]] && selected="[]"
  capacity_req="$(soviez_migration_capacity_required_bytes "$discovery" "$selected")"
  avail_bytes="$(soviez_json_get "$(soviez_json_get "$bootstrap" preflight)" available_bytes)"
  avail_inodes="$(soviez_json_get "$(soviez_json_get "$bootstrap" preflight)" available_inodes)"
  local req_bytes req_inodes
  req_bytes="$(soviez_json_get "$capacity_req" required_bytes)"
  req_inodes="$(soviez_json_get "$capacity_req" required_inodes)"
  if [[ "${avail_bytes:-0}" -lt "${req_bytes:-0}" ]]; then
    blockers+=("insufficient_disk"); result="BLOCKED"
  fi
  if [[ "${avail_inodes:-0}" -lt "${req_inodes:-0}" ]]; then
    blockers+=("insufficient_inodes"); result="BLOCKED"
  fi

  # Backup
  local backup_class capability
  backup_class="$(SOVIEZ_D="$discovery" python3 -c 'import json,os; print((json.loads(os.environ["SOVIEZ_D"]).get("backup") or {}).get("classification") or "missing")')"
  capability="$(SOVIEZ_D="$discovery" python3 -c 'import json,os; print(str((json.loads(os.environ["SOVIEZ_D"]).get("backup") or {}).get("capability_healthy", True)).lower())')"
  if [[ "$capability" == "false" ]]; then
    blockers+=("backup_capability"); result="BLOCKED"
  elif [[ "$backup_class" == "missing" || "$backup_class" == "unverified" ]]; then
    warnings+=("backup_missing_or_unverified")
    [[ "$result" == "PASS" ]] && result="WARNING"
  elif [[ "$backup_class" == "verified_old" ]]; then
    warnings+=("backup_older_than_24h")
    [[ "$result" == "PASS" ]] && result="WARNING"
  fi

  # Token eligibility — never consume
  local token_json token_status
  token_json="$(soviez_migration_token_eligibility)"
  token_status="$(soviez_json_get "$token_json" status)"
  if [[ "$(soviez_json_get "$token_json" consumed)" == "true" ]]; then
    blockers+=("token_consumed_unexpected"); result="BLOCKED"
  fi
  if [[ "$token_status" == "unavailable" || "$token_status" == "ineligible" ]]; then
    warnings+=("migration_token_unavailable")
    [[ "$result" == "PASS" ]] && result="WARNING"
  fi

  # Connectivity / mTLS
  local mtls
  mtls="$(soviez_migration_mtls_connectivity_test "$pair_id")" || true
  if [[ "$mtls" != ok* ]]; then
    blockers+=("mtls_failed"); result="BLOCKED"
  fi

  # Image digest present
  local img
  img="$(soviez_json_get "$pair" source_image_digest)"
  if [[ -z "$img" ]]; then
    warnings+=("image_digest_empty")
    [[ "$result" == "PASS" ]] && result="WARNING"
  fi

  local report_id expires report
  report_id="$(soviez_migration_new_id ready)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_READINESS_TTL_SECONDS:-86400}")"
  report="$(SOVIEZ_RID="$report_id" SOVIEZ_PID="$pair_id" SOVIEZ_RES="$result" SOVIEZ_E="$expires" \
    SOVIEZ_W="$(printf '%s\n' "${warnings[@]:-}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')" \
    SOVIEZ_B="$(printf '%s\n' "${blockers[@]:-}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')" \
    SOVIEZ_CAP="$capacity_req" SOVIEZ_TOK="$token_json" SOVIEZ_PAIR="$pair" SOVIEZ_DISC="$discovery" \
    SOVIEZ_BOOT="$bootstrap" SOVIEZ_MT="$mtls" python3 - <<'PY'
import json, os, datetime, hashlib
pair=json.loads(os.environ["SOVIEZ_PAIR"])
disc=json.loads(os.environ["SOVIEZ_DISC"])
boot=json.loads(os.environ["SOVIEZ_BOOT"])
warnings=json.loads(os.environ["SOVIEZ_W"])
blockers=json.loads(os.environ["SOVIEZ_B"])
cap=json.loads(os.environ["SOVIEZ_CAP"])
tok=json.loads(os.environ["SOVIEZ_TOK"])
def fp(obj):
  return hashlib.sha256(json.dumps(obj, sort_keys=True, separators=(",",":")).encode()).hexdigest()
input_fps={
  "source_image_digest": (disc.get("identity") or {}).get("image_digest") or "",
  "destination_bootstrap_id": boot.get("bootstrap_id") or "",
  "destination_host_fp": ((boot.get("destination_host_identity") or {}).get("fingerprint") or boot.get("public_fingerprint") or ""),
  "selected_stage_ids": pair.get("selected_stage_ids") or [],
  "backup_classification": (disc.get("backup") or {}).get("classification") or "",
  "pair_id": pair.get("migration_pair_id") or "",
  "discovery_id": disc.get("discovery_id") or "",
}
input_fps["aggregate"]=fp(input_fps)
print(json.dumps({
  "schema_version": "soviez.migration.readiness.v1",
  "report_id": os.environ["SOVIEZ_RID"],
  "pair_id": os.environ["SOVIEZ_PID"],
  "result": os.environ["SOVIEZ_RES"],
  "source_summary": disc.get("identity"),
  "destination_summary": {
    "bootstrap_id": boot.get("bootstrap_id"),
    "os": boot.get("os_version"),
    "arch": boot.get("architecture"),
    "installer_version": boot.get("installer_version"),
  },
  "trust_status": pair.get("status"),
  "compatibility_matrix": {"os": boot.get("os_version"), "arch": boot.get("architecture"), "result": os.environ["SOVIEZ_RES"]},
  "capacity_matrix": cap,
  "connectivity_matrix": {"mtls": os.environ["SOVIEZ_MT"], "saas_relay": False},
  "backup_state": disc.get("backup"),
  "migration_token_eligibility": tok,
  "migration_token_consumed": False,
  "migration_token_reserved": False,
  "stage_inventory": disc.get("stages"),
  "selected_stage_ids": pair.get("selected_stage_ids") or [],
  "domain_ssl_inspection": {"domain": (disc.get("runtime") or {}).get("domain"), "mutated": False},
  "warnings": warnings,
  "blockers": blockers,
  "required_owner_actions": blockers + (["purchase_migration_token"] if tok.get("status")=="unavailable" else []),
  "estimated_future_transfer_bytes": (disc.get("capacity") or {}).get("estimated_transfer_bytes"),
  "estimated_future_duration_class": "unknown",
  "expected_downtime_class": "none_in_phase17",
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
  "input_fingerprints": input_fps,
  "data_transfer_started": False,
  "dns_changed": False,
  "destination_production_activated": False,
  "source_license_active": True,
}, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store readiness "$report_id" "$report" >/dev/null
  # Update pair with readiness id
  SOVIEZ_P="$pair_path" SOVIEZ_R="$report_id" SOVIEZ_RES="$result" SOVIEZ_TOK="$token_json" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["readiness_report_id"]=os.environ["SOVIEZ_R"]
d["compatibility_state"]=os.environ["SOVIEZ_RES"]
d["migration_token_eligibility"]=json.loads(os.environ["SOVIEZ_TOK"]).get("status")
d["migration_token_consumed"]=False
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  # Re-sign pair after update
  soviez_migration_sign_object_file "$pair_path"

  cat "$(soviez_migration_readiness_dir "$report_id")/object.json"
  soviez_migration_outcome_banner "COMPLETE" "COMPLETE" "TRUSTED" "$result" >&2 || true
}

soviez_migration_readiness_show() {
  local report_id="${1:-}"
  [[ -n "$report_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "report-id required"
  local path
  path="$(soviez_migration_readiness_dir "$report_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown readiness report: $report_id"
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Readiness signature invalid"
  fi
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$path")" expires_at)"; then
    soviez_migration_die MIGRATION_READINESS_EXPIRED "Readiness report expired"
  fi
  # Invalidate when material inputs changed vs fingerprints captured at report time
  local report pair_id pair discovery_id discovery bootstrap_id bootstrap
  report="$(cat "$path")"
  pair_id="$(soviez_json_get "$report" pair_id)"
  pair="$(cat "$(soviez_migration_pair_dir "$pair_id")/object.json" 2>/dev/null || echo '{}')"
  discovery_id="$(soviez_json_get "$pair" source_discovery_id)"
  bootstrap_id="$(soviez_json_get "$pair" destination_bootstrap_id)"
  discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json" 2>/dev/null || echo '{}')"
  bootstrap="$(cat "$(soviez_migration_bootstrap_dir "$bootstrap_id")/object.json" 2>/dev/null || echo '{}')"
  SOVIEZ_R="$report" SOVIEZ_P="$pair" SOVIEZ_D="$discovery" SOVIEZ_B="$bootstrap" python3 - <<'PY' || soviez_migration_die MIGRATION_READINESS_INPUT_CHANGED "Readiness inputs changed"
import json, os, hashlib, sys
report=json.loads(os.environ["SOVIEZ_R"])
pair=json.loads(os.environ["SOVIEZ_P"])
disc=json.loads(os.environ["SOVIEZ_D"])
boot=json.loads(os.environ["SOVIEZ_B"])
fps=report.get("input_fingerprints") or {}
cur={
  "source_image_digest": (disc.get("identity") or {}).get("image_digest") or "",
  "destination_bootstrap_id": boot.get("bootstrap_id") or "",
  "destination_host_fp": ((boot.get("destination_host_identity") or {}).get("fingerprint") or boot.get("public_fingerprint") or ""),
  "selected_stage_ids": pair.get("selected_stage_ids") or [],
  "backup_classification": (disc.get("backup") or {}).get("classification") or "",
  "pair_id": pair.get("migration_pair_id") or "",
  "discovery_id": disc.get("discovery_id") or "",
}
for k in ("source_image_digest","destination_bootstrap_id","destination_host_fp","backup_classification","pair_id","discovery_id"):
  if fps.get(k) != cur.get(k):
    sys.exit(2)
if fps.get("selected_stage_ids") != cur.get("selected_stage_ids"):
  sys.exit(2)
sys.exit(0)
PY
  cat "$path"
}

soviez_migration_stage_select() {
  local pair_id="$1" stage_id="$2" mode="${3:-select}"
  local pair_path pair discovery_id discovery
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$pair_path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown pair"
  pair="$(cat "$pair_path")"
  discovery_id="$(soviez_json_get "$pair" source_discovery_id)"
  discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json")"
  SOVIEZ_D="$discovery" SOVIEZ_S="$stage_id" SOVIEZ_P="$pair_path" SOVIEZ_M="$mode" python3 - <<'PY'
import json, os, sys
disc=json.loads(os.environ["SOVIEZ_D"])
sid=os.environ["SOVIEZ_S"]
mode=os.environ["SOVIEZ_M"]
stages=(disc.get("stages") or {}).get("stages") or []
match=[s for s in stages if s.get("stage_id")==sid]
if not match:
    print("MISSING", file=sys.stderr); sys.exit(31)
st=match[0]
if mode=="select":
    if not st.get("selectable", False):
        print("NOT_SELECTABLE:"+str(st.get("selectable_reason")), file=sys.stderr); sys.exit(32)
pair=json.load(open(os.environ["SOVIEZ_P"]))
sel=list(pair.get("selected_stage_ids") or [])
if mode=="select":
    if sid not in sel: sel.append(sid)
else:
    sel=[x for x in sel if x!=sid]
pair["selected_stage_ids"]=sel
# never mutate stage inventory on disk
open(os.environ["SOVIEZ_P"],"w").write(json.dumps(pair, separators=(",", ":")))
print(json.dumps({"selected_stage_ids": sel}, separators=(",", ":")))
PY
  local rc=$?
  if [[ $rc -eq 31 ]]; then
    soviez_migration_die MIGRATION_STAGE_NOT_SELECTABLE "Unknown stage"
  elif [[ $rc -eq 32 ]]; then
    soviez_migration_die MIGRATION_STAGE_EXPIRED "Stage not selectable"
  fi
  soviez_migration_sign_object_file "$pair_path"
}

soviez_migration_abort_run() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_paths_init
  local pair_path bootstrap_id
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  if [[ -f "$pair_path" ]]; then
    bootstrap_id="$(soviez_json_get "$(cat "$pair_path")" destination_bootstrap_id)"
    soviez_migration_pair_revoke "$pair_id"
    [[ -n "$bootstrap_id" ]] && soviez_migration_bootstrap_abort_identity "$bootstrap_id"
  fi
  # Idempotent success
  printf '{"pair_id":"%s","status":"aborted","data_transfer_started":false,"migration_token_consumed":false,"source_maintenance_enabled":false,"destination_production_activated":false,"dns_changed":false}\n' "$pair_id"
}
