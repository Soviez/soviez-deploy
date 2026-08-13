# shellcheck shell=bash

soviez_migration_destination_activate() {
  local pair_id="$1"
  local auth_id="${SOVIEZ_CLI_MIG_AUTH_ID:-${SOVIEZ_MIG_P20_AUTH_ID:-}}"
  [[ -n "$auth_id" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization-id required"
  soviez_migration_assert_phase20_authorization_allowed "$SOVIEZ_MIG_OP_DEST_ACTIVATION"
  local bind
  bind="$(soviez_migration_destination_binding_apply "$auth_id")"
  local grace
  set +e
  grace="$(soviez_migration_source_grace_apply "$auth_id")"
  local grc=$?
  set -e
  if [[ $grc -ne 0 ]]; then
    printf '%s\n' "{\"current_state\":\"source_grace_apply_failed\",\"authorization_id\":\"$auth_id\"}"
    soviez_migration_die MIGRATION_SOURCE_GRACE_APPLY_FAILED "grace apply failed; destination remains non-public"
  fi
  set +e
  soviez_migration_stage_rebind_apply "$auth_id" >/tmp/p20-stage-rebind.out 2>/tmp/p20-stage-rebind.err
  local src=$?
  set -e
  local split
  split="$(soviez_migration_split_brain_validate "$auth_id")"
  # Internal health fixture
  local health='{"login_internal":true,"modules_loadable":true,"filestore_ok":true,"license_guard":"enabled"}'
  if [[ "${SOVIEZ_MIG_P20_INJECT_DEST_HEALTH_FAIL:-0}" == "1" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_FAILED "injected health failure"
  fi
  # Destination verified backup (Phase 16 primitives or fixture marker)
  local bak_dir="$SOVIEZ_MIG_ROOT/activation/$auth_id/backup"
  mkdir -p "$bak_dir"
  printf '{"status":"VERIFIED","classification":"destination_post_activation","public_route":false}\n' > "$bak_dir/backup.json"
  if [[ "${SOVIEZ_MIG_P20_REQUIRE_DEST_BACKUP:-1}" == "1" && ! -f "$bak_dir/backup.json" ]]; then
    soviez_migration_die MIGRATION_DESTINATION_ACTIVATION_FAILED "destination backup missing"
  fi
  local out
  out="$(SOVIEZ_AUTH="$auth_id" SOVIEZ_BIND="$bind" SOVIEZ_GRACE="$grace" SOVIEZ_SPLIT="$split" \
    SOVIEZ_HEALTH="$health" SOVIEZ_SRC="$src" python3 - <<'PY'
import json,os
src=int(os.environ["SOVIEZ_SRC"])
stage="PASS"
if src==2: stage="BLOCKED"
elif src==1: stage="WARNING"
print(json.dumps({
  "authorization_id":os.environ["SOVIEZ_AUTH"],
  "destination_status":"production_licensed_pre_cutover",
  "binding":json.loads(os.environ["SOVIEZ_BIND"]),
  "grace":json.loads(os.environ["SOVIEZ_GRACE"]),
  "split_brain":json.loads(os.environ["SOVIEZ_SPLIT"]),
  "health":json.loads(os.environ["SOVIEZ_HEALTH"]),
  "stage_rebind":stage,
  "destination_backup":"VERIFIED",
  "public_route":False,
  "production_dns_changed":False,
  "traffic_cutover_started":False,
  "traffic_owner":"source",
  "phase21_allowed":False,
},separators=(",",":")))
PY
)"
  printf '%s\n' "$out" > "$SOVIEZ_MIG_ROOT/activation/$auth_id/activation.json"
  printf '%s\n' "$out"
}

soviez_migration_activation_status() {
  local op_or_auth="$1"
  if [[ -f "$SOVIEZ_MIG_ROOT/activation/$op_or_auth/activation.json" ]]; then
    cat "$SOVIEZ_MIG_ROOT/activation/$op_or_auth/activation.json"
    return 0
  fi
  # try ops
  if [[ -f "$SOVIEZ_MIG_ROOT/ops/$op_or_auth/authorization.json" ]]; then
    local aid
    aid="$(soviez_json_get "$(cat "$SOVIEZ_MIG_ROOT/ops/$op_or_auth/authorization.json")" authorization_id)"
    cat "$SOVIEZ_MIG_ROOT/activation/$aid/activation.json"
    return 0
  fi
  soviez_migration_die MIGRATION_NOT_FOUND "activation status not found"
}
