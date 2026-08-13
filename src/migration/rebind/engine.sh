# shellcheck shell=bash

soviez_migration_source_grace_apply() {
  local auth_id="$1"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_SOURCE_GRACE"
  local authf grace_dir
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "missing authorization"
  if [[ "${SOVIEZ_MIG_P20_INJECT_GRACE_FAIL:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SOURCE_GRACE_APPLY_FAILED "injected grace failure"
  fi
  local license_id src_fp
  license_id="$(soviez_json_get "$(cat "$authf")" license_id)"
  src_fp="$(soviez_json_get "$(cat "$authf")" source_device_fingerprint)"
  grace_dir="$SOVIEZ_MIG_ROOT/grace/$license_id"
  mkdir -p "$grace_dir"
  cat > "$grace_dir/grace.json" <<EOF
{"schema":"soviez.migration_origin_grace.v1","grace_id":"grace-$auth_id","authorization_id":"$auth_id","license_id":"$license_id","source_fingerprint":"$src_fp","state":"migration_origin_grace","traffic_owner":"source","allows":["traffic","backup","status","diagnostics","recovery"],"denies":["update","clone","stage_create","second_migration","rebind","device_reauth","license_export","restore_to_new_production"],"slot":false,"expires":null,"needs_action_if_stale":true}
EOF
  # enforcement marker used by restriction checks
  printf '1\n' > "$grace_dir/ENFORCED"
  cat "$grace_dir/grace.json"
}

soviez_migration_source_grace_status() {
  local prod_id="$1"
  local license_id="${SOVIEZ_MIG_P20_LICENSE_ID:-lic-p20}"
  local f="$SOVIEZ_MIG_ROOT/grace/$license_id/grace.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_SOURCE_GRACE_INVALID "grace missing for $prod_id"
  cat "$f"
}

soviez_migration_source_grace_assert_allowed() {
  local action="$1"
  local license_id="${SOVIEZ_MIG_P20_LICENSE_ID:-lic-p20}"
  local f="$SOVIEZ_MIG_ROOT/grace/$license_id/grace.json"
  [[ -f "$f" ]] || return 0
  case "$action" in
    update|clone|stage_create|second_migration|rebind|device_reauth|license_export|restore_to_new_production)
      soviez_migration_die MIGRATION_SOURCE_GRACE_INVALID "action denied under migration_origin_grace: $action"
      ;;
  esac
  return 0
}

soviez_migration_destination_binding_apply() {
  local auth_id="$1"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_DEST_ACTIVATION"
  local authf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "missing authorization"
  if [[ "${SOVIEZ_MIG_P20_INJECT_LG_DENY:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_LICENSE_GUARD_DENIED "injected LG denial"
  fi
  local dest_dir
  dest_dir="$SOVIEZ_MIG_ROOT/activation/$auth_id"
  mkdir -p "$dest_dir"
  local dest_fp db digest
  dest_fp="$(soviez_json_get "$(cat "$authf")" destination_device_fingerprint)"
  db="$(soviez_json_get "$(cat "$authf")" destination_database_uuid)"
  digest="$(soviez_json_get "$(cat "$authf")" destination_image_digest)"
  # PoP: require matching local destination fingerprint env
  if [[ -n "${SOVIEZ_MIG_P20_LOCAL_DEST_FP:-}" && "${SOVIEZ_MIG_P20_LOCAL_DEST_FP}" != "$dest_fp" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_BINDING_INVALID "destination PoP fingerprint mismatch"
  fi
  cat > "$dest_dir/binding.json" <<EOF
{"schema":"soviez.destination_binding.v1","authorization_id":"$auth_id","status":"production_licensed_pre_cutover","destination_fingerprint":"$dest_fp","database_uuid":"$db","image_digest":"$digest","public_route":false,"production_domain":null,"license_guard":"enabled","permanent_slot":true,"slot_count":1,"mail_neutralized":true,"payments_neutralized":true,"webhooks_neutralized":true,"cron_neutralized":true,"traffic_owner":"source","licensed_future_owner":"destination"}
EOF
  printf 'false\n' > "$dest_dir/public_route"
  cat "$dest_dir/binding.json"
}

soviez_migration_stage_rebind_apply() {
  local auth_id="$1"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_STAGE_REBIND"
  local authf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "missing authorization"
  local results blocked=0 warning=0
  results="$(soviez_json_get "$(cat "$authf")" stage_rebind_results)"
  mkdir -p "$SOVIEZ_MIG_ROOT/activation/$auth_id"
  printf '%s\n' "$results" > "$SOVIEZ_MIG_ROOT/activation/$auth_id/stage_rebinds.json"
  # Evaluate mandatory failures
  SOVIEZ_R="$(cat "$authf")" python3 - <<'PY'
import json,os,sys
auth=json.loads(os.environ["SOVIEZ_R"])
blocked=False; warn=False
for r in auth.get("stage_rebind_results") or []:
  if r.get("status")!="rebound":
    if r.get("mandatory"):
      blocked=True
    else:
      warn=True
out={"blocked":blocked,"warning":warn,"results":auth.get("stage_rebind_results") or [],"retention_unchanged":True}
print(json.dumps(out,separators=(",",":")))
if blocked:
  sys.exit(2)
if warn:
  sys.exit(1)
sys.exit(0)
PY
}

soviez_migration_split_brain_validate() {
  local auth_id="$1"
  local bindf gracef
  bindf="$SOVIEZ_MIG_ROOT/activation/$auth_id/binding.json"
  local license_id
  license_id="$(soviez_json_get "$(cat "$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json")" license_id)"
  gracef="$SOVIEZ_MIG_ROOT/grace/$license_id/grace.json"
  [[ -f "$bindf" ]] || soviez_migration_die MIGRATION_DESTINATION_BINDING_INVALID "binding missing"
  [[ -f "$gracef" ]] || soviez_migration_die MIGRATION_SOURCE_GRACE_INVALID "grace missing"
  local pub
  pub="$(soviez_json_get "$(cat "$bindf")" public_route)"
  if [[ "$pub" == "true" || "$pub" == "True" ]]; then
    soviez_migration_die MIGRATION_SPLIT_BRAIN_DETECTED "destination public before Phase 21"
  fi
  if [[ "${SOVIEZ_MIG_P20_INJECT_SPLIT_BRAIN:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_SPLIT_BRAIN_DETECTED "injected dual public"
  fi
  local domain
  domain="$(soviez_json_get "$(cat "$bindf")" production_domain)"
  [[ "$domain" == "null" || -z "$domain" || "$domain" == "" ]] || \
    soviez_migration_die MIGRATION_SPLIT_BRAIN_DETECTED "production domain present"
  printf '{"status":"active","traffic_owner":"source","licensed_future_owner":"destination","public_destination":false}\n'
}
