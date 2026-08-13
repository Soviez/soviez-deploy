# shellcheck shell=bash

soviez_migration_resolve_bootstrap_code() {
  local code="${1:-}"
  [[ -n "$code" ]] || soviez_migration_die MIGRATION_DESTINATION_REQUIRED "Destination bootstrap code required"
  soviez_migration_paths_init
  local path="$SOVIEZ_MIG_CODE_DIR/$code.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_DESTINATION_INVALID "Unknown bootstrap code"
  local doc used expires
  doc="$(cat "$path")"
  used="$(soviez_json_get "$doc" used)"
  expires="$(soviez_json_get "$doc" expires_at)"
  if [[ "$used" == "true" || "$used" == "True" ]]; then
    soviez_migration_die MIGRATION_PAIR_REPLAY_DENIED "Bootstrap code already used"
  fi
  if soviez_migration_is_expired "$expires"; then
    soviez_migration_die MIGRATION_BOOTSTRAP_EXPIRED "Bootstrap code expired"
  fi
  printf '%s' "$doc"
}

soviez_migration_mark_code_used() {
  local code="$1"
  local path="$SOVIEZ_MIG_CODE_DIR/$code.json"
  [[ -f "$path" ]] || return 0
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["used"]=True
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
}

soviez_migration_pair_run() {
  local production_id="${1:-}" code="${2:-}" \
    confirm_src_fp="${3:-}" confirm_dst_fp="${4:-}" \
    confirm_license="${5:-}" confirm_prod="${6:-}" confirm_boot="${7:-}" \
    confirm_flag="${8:-0}"

  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local prod code_doc bootstrap_id bootstrap_obj discovery_id discovery_obj
  prod="$(soviez_migration_resolve_production "$production_id")" || exit $?
  code_doc="$(soviez_migration_resolve_bootstrap_code "$code")" || exit $?
  bootstrap_id="$(soviez_json_get "$code_doc" bootstrap_id)"
  bootstrap_obj="$(cat "$(soviez_migration_bootstrap_dir "$bootstrap_id")/object.json")"
  [[ "$(soviez_json_get "$bootstrap_obj" revocation_state)" == "active" ]] || \
    soviez_migration_die MIGRATION_BOOTSTRAP_REVOKED "Bootstrap identity revoked"
  if soviez_migration_is_expired "$(soviez_json_get "$bootstrap_obj" expires_at)"; then
    soviez_migration_die MIGRATION_BOOTSTRAP_EXPIRED "Bootstrap identity expired"
  fi

  # Prefer latest discovery for this production
  discovery_id="${SOVIEZ_MIG_DISCOVERY_ID:-}"
  if [[ -z "$discovery_id" ]]; then
    discovery_id="$(SOVIEZ_PID="$production_id" SOVIEZ_D="$SOVIEZ_MIG_DISCOVERY_DIR" python3 - <<'PY'
import json, os, pathlib
pid=os.environ["SOVIEZ_PID"]
root=pathlib.Path(os.environ["SOVIEZ_D"])
best=None; best_t=""
for d in root.iterdir() if root.exists() else []:
  p=d/"object.json"
  if not p.exists(): continue
  try: obj=json.loads(p.read_text())
  except Exception: continue
  ident=obj.get("identity") or {}
  if (ident.get("production_id") or "") != pid: continue
  t=obj.get("created_at") or ""
  if t >= best_t:
    best_t=t; best=obj.get("discovery_id") or d.name
print(best or "")
PY
)"
  fi
  [[ -n "$discovery_id" ]] || soviez_migration_die MIGRATION_SOURCE_REQUIRED "Run --migration-discover first"
  discovery_obj="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json")"

  local src_fp dst_fp license_id
  src_fp="$(soviez_json_get "$(soviez_json_get "$discovery_obj" identity)" host_identity 2>/dev/null || true)"
  # host_identity is nested JSON string sometimes — parse carefully
  src_fp="$(SOVIEZ_D="$discovery_obj" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_D"]); print(d["identity"]["host_identity"]["fingerprint"])')"
  dst_fp="$(soviez_json_get "$bootstrap_obj" public_fingerprint)"
  license_id="$(SOVIEZ_D="$discovery_obj" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_D"]); print(d["identity"].get("license_id") or "")')"

  # Owner confirmation
  if [[ ! -t 0 || "$confirm_flag" == "1" ]]; then
    [[ "$confirm_src_fp" == "$src_fp" ]] || soviez_migration_die MIGRATION_PAIR_FINGERPRINT_MISMATCH "Source fingerprint confirmation mismatch"
    [[ "$confirm_dst_fp" == "$dst_fp" ]] || soviez_migration_die MIGRATION_PAIR_FINGERPRINT_MISMATCH "Destination fingerprint confirmation mismatch"
    [[ "$confirm_license" == "$license_id" ]] || soviez_migration_die MIGRATION_PAIR_IDENTITY_MISMATCH "License confirmation mismatch"
    [[ "$confirm_prod" == "$production_id" ]] || soviez_migration_die MIGRATION_PAIR_IDENTITY_MISMATCH "Production confirmation mismatch"
    [[ "$confirm_boot" == "$bootstrap_id" ]] || soviez_migration_die MIGRATION_PAIR_IDENTITY_MISMATCH "Bootstrap confirmation mismatch"
  else
    echo "Confirm pairing fingerprints:" >&2
    echo "  source_fp=$src_fp" >&2
    echo "  destination_fp=$dst_fp" >&2
    echo "  license_id=$license_id" >&2
    echo "  production_id=$production_id" >&2
    echo "  bootstrap_id=$bootstrap_id" >&2
    read -r -p "Type CONFIRM to continue: " ans
    [[ "$ans" == "CONFIRM" ]] || soviez_migration_die MIGRATION_PAIR_OWNER_CONFIRMATION_REQUIRED "Owner confirmation required"
  fi

  local pair_id op_id challenge nonce expires trust_dir mtls_result
  pair_id="$(soviez_migration_new_id pair)"
  op_id="$(soviez_migration_new_id pair-op)"
  nonce="$(openssl rand -hex 16)"
  challenge="$(SOVIEZ_N="$nonce" SOVIEZ_P="$production_id" SOVIEZ_L="$license_id" SOVIEZ_B="$bootstrap_id" \
    SOVIEZ_SF="$src_fp" SOVIEZ_DF="$dst_fp" python3 - <<'PY'
import json, os, hashlib
raw="|".join([os.environ[k] for k in ("SOVIEZ_N","SOVIEZ_P","SOVIEZ_L","SOVIEZ_B","SOVIEZ_SF","SOVIEZ_DF")])
print(hashlib.sha256(raw.encode()).hexdigest())
PY
)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_PAIR_TTL_SECONDS:-86400}")"

  trust_dir="$(soviez_migration_mtls_issue_pair "$pair_id" "src-$production_id" "dst-$bootstrap_id")"
  mtls_result="$(soviez_migration_mtls_connectivity_test "$pair_id")" || \
    soviez_migration_die MIGRATION_MTLS_FAILED "mTLS connectivity failed"

  soviez_migration_mark_code_used "$code"

  local image_digest db_uuid
  image_digest="$(SOVIEZ_D="$discovery_obj" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_D"]); print(d["identity"].get("image_digest") or "")')"
  db_uuid="$(SOVIEZ_D="$discovery_obj" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_D"]); print(d["identity"].get("database_uuid") or "")')"

  local pair_obj
  pair_obj="$(SOVIEZ_PID="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_DID="$discovery_id" \
    SOVIEZ_PROD="$production_id" SOVIEZ_L="$license_id" SOVIEZ_DB="$db_uuid" SOVIEZ_IMG="$image_digest" \
    SOVIEZ_BID="$bootstrap_id" SOVIEZ_SF="$src_fp" SOVIEZ_DF="$dst_fp" SOVIEZ_E="$expires" \
    SOVIEZ_CH="$challenge" SOVIEZ_TD="$trust_dir" SOVIEZ_MT="$mtls_result" \
    SOVIEZ_BO="$bootstrap_obj" SOVIEZ_HO="$(soviez_migration_host_identity)" python3 - <<'PY'
import json, os, datetime
boot=json.loads(os.environ["SOVIEZ_BO"])
print(json.dumps({
  "schema_version": "soviez.migration_pair.v1",
  "migration_pair_id": os.environ["SOVIEZ_PID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "source_discovery_id": os.environ["SOVIEZ_DID"],
  "source_production_id": os.environ["SOVIEZ_PROD"],
  "source_license_id": os.environ["SOVIEZ_L"],
  "source_host_identity": json.loads(os.environ["SOVIEZ_HO"]),
  "source_database_uuid": os.environ["SOVIEZ_DB"],
  "source_image_digest": os.environ["SOVIEZ_IMG"],
  "destination_bootstrap_id": os.environ["SOVIEZ_BID"],
  "destination_host_identity": boot.get("destination_host_identity"),
  "destination_architecture": boot.get("architecture"),
  "destination_os": boot.get("os_version"),
  "destination_installer_version": boot.get("installer_version"),
  "destination_image_digest_status": boot.get("expected_source_compatible_image_digest"),
  "source_fingerprint": os.environ["SOVIEZ_SF"],
  "destination_fingerprint": os.environ["SOVIEZ_DF"],
  "trust_certificate_refs": {"dir": os.environ["SOVIEZ_TD"], "mtls": os.environ["SOVIEZ_MT"]},
  "challenge": os.environ["SOVIEZ_CH"],
  "pair_created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "pair_expires_at": os.environ["SOVIEZ_E"],
  "owner_confirmation_state": "confirmed",
  "compatibility_state": "pending",
  "backup_state": "pending",
  "migration_token_eligibility": "not_checked",
  "migration_token_consumed": False,
  "data_transfer_started": False,
  "source_maintenance_enabled": False,
  "dns_changed": False,
  "destination_production_activated": False,
  "source_license_active": True,
  "selected_stage_ids": [],
  "readiness_report_id": "",
  "status": "trusted",
  "failure_code": "",
  "recovery_state": "",
  "aborted": False,
}, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store pair "$pair_id" "$pair_obj" >/dev/null
  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '{"operation_id":"%s","operation_type":"%s","current_state":"completed","pair_id":"%s","environment_id":"%s"}\n' \
    "$op_id" "$SOVIEZ_MIG_OP_PAIRING" "$pair_id" "$production_id" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"

  cat "$(soviez_migration_pair_dir "$pair_id")/object.json"
}

soviez_migration_pair_status() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  local path
  path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown pair: $pair_id"
  cat "$path"
}

soviez_migration_pair_revoke() {
  local pair_id="$1"
  local path trust
  path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  [[ -f "$path" ]] || return 0
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["status"]="aborted"
d["aborted"]=True
d["migration_token_consumed"]=False
d["data_transfer_started"]=False
d["source_maintenance_enabled"]=False
d["destination_production_activated"]=False
d["dns_changed"]=False
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  trust="$SOVIEZ_MIG_TRUST_DIR/$pair_id"
  if [[ -d "$trust" ]]; then
    # Revoke by removing private keys only; keep certs as evidence metadata without private material copy in evidence
    rm -f "$trust"/*.key
    printf 'revoked\n' > "$trust/REVOKED"
  fi
}
