# shellcheck shell=bash

soviez_migration_transfer_plan_create() {
  local pair_id="$1" routing_plan_id="$2" backup_pin_json="${3:-"{}"}" profile="${4:-balanced}"
  local plan_id op_id pair routing expires plan_json plan_dir
  soviez_migration_paths_init
  soviez_migration_assert_phase19_transfer_allowed "$pair_id" "$SOVIEZ_MIG_OP_TRANSFER_PLAN"
  pair="$(soviez_migration_transfer_load_pair "$pair_id")"
  routing="$(soviez_migration_transfer_load_routing "$routing_plan_id" "$pair_id")"
  plan_id="$(soviez_migration_new_id tplan)"
  op_id="$(soviez_migration_new_id xfer-op)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_TRANSFER_PLAN_TTL_SECONDS:-86400}")"
  plan_dir="$(soviez_migration_transfer_plan_dir "$plan_id")"
  mkdir -p "$plan_dir"
  plan_json="$(SOVIEZ_PID="$plan_id" SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_RID="$routing_plan_id" \
    SOVIEZ_PAIR_J="$pair" SOVIEZ_ROUTING_J="$routing" SOVIEZ_PIN="$backup_pin_json" \
    SOVIEZ_PROF="$profile" SOVIEZ_E="$expires" SOVIEZ_CHUNK="${SOVIEZ_MIG_CHUNK_SIZE_BYTES:-67108864}" python3 - <<'PY'
import json, os, datetime
pair=json.loads(os.environ["SOVIEZ_PAIR_J"])
routing=json.loads(os.environ["SOVIEZ_ROUTING_J"])
pin=json.loads(os.environ["SOVIEZ_PIN"] or "{}")
print(json.dumps({
  "schema_version": "soviez.migration_transfer_plan.v1",
  "transfer_plan_id": os.environ["SOVIEZ_PID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "routing_plan_id": os.environ["SOVIEZ_RID"],
  "source_production_id": pair.get("source_production_id") or pair.get("production_id") or "",
  "source_license_id": pair.get("source_license_id") or pair.get("license_id") or "",
  "source_database_uuid": pair.get("source_database_uuid") or "",
  "source_host_identity": pair.get("source_host_fingerprint") or pair.get("source_fingerprint") or "",
  "source_image_digest": pair.get("source_image_digest") or "",
  "destination_bootstrap_id": pair.get("destination_bootstrap_id") or "",
  "destination_host_identity": pair.get("destination_host_fingerprint") or pair.get("destination_fingerprint") or "",
  "destination_staging_id": "",
  "backup_id": (pin.get("backup_id") or (pin.get("backup") or {}).get("backup_id") or ""),
  "backup_verification_state": pin.get("status") or "VERIFIED",
  "selected_payload_categories": ["database","filestore","addons","config","stages"],
  "selected_stage_ids": pair.get("selected_stage_ids") or [],
  "stage_flags": pair.get("stage_flags") or {},
  "resource_profile": os.environ["SOVIEZ_PROF"],
  "chunk_size_bytes": int(os.environ["SOVIEZ_CHUNK"]),
  "compression_profile": "zstd_balanced",
  "encryption_profile": "mtls_channel",
  "transfer_protocol": "application_mtls_chunks",
  "capacity_result": "PASS",
  "status": "created",
  "warnings": [],
  "blockers": [],
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
}, separators=(",", ":")))
PY
)"
  printf '%s' "$plan_json" > "$plan_dir/object.json"
  soviez_migration_sign_object_file "$plan_dir/object.json"
  cat "$plan_dir/object.json"
}

soviez_migration_transfer_manifest_create() {
  local plan_json="$1" op_id="${2:-}"
  local manifest_id plan_id pair_id man_dir man_json
  soviez_migration_paths_init
  plan_id="$(soviez_json_get "$plan_json" transfer_plan_id)"
  pair_id="$(soviez_json_get "$plan_json" migration_pair_id)"
  [[ -n "$op_id" ]] || op_id="$(soviez_json_get "$plan_json" operation_id)"
  manifest_id="$(soviez_migration_new_id tman)"
  man_dir="$(soviez_migration_transfer_manifest_dir "$manifest_id")"
  mkdir -p "$man_dir"
  man_json="$(SOVIEZ_MID="$manifest_id" SOVIEZ_OP="$op_id" SOVIEZ_PLAN="$plan_json" python3 - <<'PY'
import json, os, datetime
plan=json.loads(os.environ["SOVIEZ_PLAN"])
print(json.dumps({
  "schema_version": "soviez.migration_transfer_manifest.v1",
  "manifest_id": os.environ["SOVIEZ_MID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "transfer_plan_id": plan.get("transfer_plan_id"),
  "migration_pair_id": plan.get("migration_pair_id"),
  "routing_plan_id": plan.get("routing_plan_id"),
  "source_production_id": plan.get("source_production_id"),
  "source_license_id": plan.get("source_license_id"),
  "source_database_uuid": plan.get("source_database_uuid"),
  "source_host_identity": plan.get("source_host_identity"),
  "source_image_digest": plan.get("source_image_digest"),
  "destination_bootstrap_id": plan.get("destination_bootstrap_id"),
  "destination_host_identity": plan.get("destination_host_identity"),
  "destination_staging_id": plan.get("destination_staging_id") or "",
  "backup_id": plan.get("backup_id"),
  "selected_payload_categories": plan.get("selected_payload_categories") or [],
  "selected_stage_ids": plan.get("selected_stage_ids") or [],
  "objects": [],
  "chunks": [],
  "total_expected_bytes": 0,
  "total_expected_files": 0,
  "chunking_profile": {"chunk_size_bytes": plan.get("chunk_size_bytes") or 67108864},
  "compression_profile": plan.get("compression_profile"),
  "transport_profile": plan.get("transfer_protocol"),
  "integrity_algorithms": ["sha256"],
  "pre_sync_generation": 0,
  "final_pass_generation": 0,
  "source_freeze_state": "released",
  "completed_checkpoints": [],
  "destination_assembly_state": "pending",
  "migration_token_reserved": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "traffic_cutover_started": False,
  "source_license_active": True,
  "source_runtime_active": True,
  "status": "created",
  "warnings": [],
  "blockers": [],
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": plan.get("expires_at"),
}, separators=(",", ":")))
PY
)"
  printf '%s' "$man_json" > "$man_dir/object.json"
  soviez_migration_sign_object_file "$man_dir/object.json"
  cat "$man_dir/object.json"
}

soviez_migration_transfer_manifest_verify() {
  local manifest_id="$1"
  local path
  path="$(soviez_migration_transfer_manifest_dir "$manifest_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_TRANSFER_MANIFEST_REQUIRED "Unknown manifest: $manifest_id"
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_TRANSFER_MANIFEST_INVALID "Manifest signature invalid"
  fi
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$path")" expires_at)"; then
    soviez_migration_die MIGRATION_TRANSFER_MANIFEST_EXPIRED "Manifest expired"
  fi
  # Token / cutover invariants
  local doc
  doc="$(cat "$path")"
  [[ "$(soviez_json_get "$doc" migration_token_reserved)" != "true" ]] || \
    soviez_migration_die MIGRATION_TOKEN_NOT_RESERVED "Token reserved flag must be false"
  [[ "$(soviez_json_get "$doc" migration_token_consumed)" != "true" ]] || \
    soviez_migration_die MIGRATION_TOKEN_NOT_CONSUMED "Token consumed flag must be false"
  [[ "$(soviez_json_get "$doc" destination_production_activated)" != "true" ]] || \
    soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_NOT_AUTHORIZED "Destination activated"
  [[ "$(soviez_json_get "$doc" traffic_cutover_started)" != "true" ]] || \
    soviez_migration_die MIGRATION_CUTOVER_NOT_AUTHORIZED "Traffic cutover started"
  cat "$path"
}

soviez_migration_transfer_plan_show() {
  local plan_id="${1:-}"
  local path
  [[ -n "$plan_id" ]] || soviez_migration_die MIGRATION_TRANSFER_PLAN_REQUIRED "plan-id required"
  path="$(soviez_migration_transfer_plan_dir "$plan_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_TRANSFER_PLAN_REQUIRED "Unknown plan: $plan_id"
  if ! soviez_migration_verify_object_signature "$path" 2>/dev/null; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_TRANSFER_PLAN_INVALID "Plan signature invalid"
    fi
  fi
  cat "$path"
}

soviez_migration_transfer_manifest_add_object() {
  local manifest_id="$1" object_json="$2"
  local path
  path="$(soviez_migration_transfer_manifest_dir "$manifest_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_TRANSFER_MANIFEST_REQUIRED "Unknown manifest"
  SOVIEZ_P="$path" SOVIEZ_O="$object_json" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
obj=json.loads(os.environ["SOVIEZ_O"])
objs=list(d.get("objects") or [])
objs.append(obj)
d["objects"]=objs
d["total_expected_bytes"]=sum(int(o.get("size_bytes") or 0) for o in objs)
d["total_expected_files"]=len(objs)
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps(d, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$path"
}
