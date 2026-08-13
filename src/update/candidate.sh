# shellcheck shell=bash

# Update candidate is NOT a Stage License product and must not burn a Production slot.

soviez_update_candidate_create() {
  local op_id="$1" prod_json="$2" target_digest="$3"
  local cdir
  cdir="$(soviez_update_candidate_dir "$op_id")"
  mkdir -p "$cdir/db" "$cdir/filestore" "$cdir/runtime" "$cdir/network"
  chmod 700 "$cdir"

  local tenant_id db_uuid license_id
  tenant_id="$(soviez_json_get "$prod_json" tenant_id)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid)"
  license_id="$(soviez_json_get "$prod_json" license_id)"

  local bdir
  bdir="$(soviez_update_backup_dir "$op_id")"
  cp -a "$bdir/db/." "$cdir/db/" || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate DB clone failed"
  cp -a "$bdir/filestore/." "$cdir/filestore/" || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate filestore clone failed"

  local live_db live_fs
  live_db="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"
  live_fs="$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || true)"
  if [[ -n "$live_db" && -e "$live_db" ]]; then
    case "$cdir/db" in "$live_db"|"$live_db"/*) soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate DB collides with live path" ;; esac
  fi
  if [[ -n "$live_fs" && -e "$live_fs" ]]; then
    case "$cdir/filestore" in "$live_fs"|"$live_fs"/*) soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate filestore collides with live path" ;; esac
  fi

  local container_name="soviez-upd-cand-${op_id}"
  local network_name="soviez-upd-net-${op_id}"
  printf 'container=%s\nnetwork=%s\ndigest=%s\nrole=update_candidate\nlicense_slot=none\ntemporary=1\n' \
    "$container_name" "$network_name" "$target_digest" > "$cdir/runtime/identity.txt"
  printf '%s' "$db_uuid" > "$cdir/runtime/database_uuid.txt"
  printf '%s' "$license_id" > "$cdir/runtime/license_id.txt"
  printf '%s' "$tenant_id" > "$cdir/runtime/production_tenant_id.txt"

  cat > "$cdir/runtime/neutralization.env" <<EOF
SOVIEZ_CANDIDATE=1
SOVIEZ_MAIL_DISABLED=1
SOVIEZ_CRON_DISABLED=1
SOVIEZ_WEBHOOKS_DISABLED=1
SOVIEZ_PAYMENT_DISABLED=1
SOVIEZ_OUTBOUND_RESTRICTED=1
SOVIEZ_BACKGROUND_JOBS=neutralized
EOF

  if soviez_update_real_docker_enabled 2>/dev/null; then
    local db_name="upd_$(printf '%s' "$op_id" | tr -cd 'a-zA-Z0-9' | cut -c1-20)"
    printf '%s' "$db_uuid" > "$cdir/runtime/database_uuid.txt"
    printf '%s' "$license_id" > "$cdir/runtime/license_id.txt"
    printf '%s' "$tenant_id" > "$cdir/runtime/production_tenant_id.txt"
    cat > "$cdir/runtime/neutralization.env" <<EOF
SOVIEZ_CANDIDATE=1
SOVIEZ_MAIL_DISABLED=1
SOVIEZ_CRON_DISABLED=1
SOVIEZ_WEBHOOKS_DISABLED=1
SOVIEZ_PAYMENT_DISABLED=1
SOVIEZ_OUTBOUND_RESTRICTED=1
SOVIEZ_BACKGROUND_JOBS=neutralized
EOF
    soviez_update_real_candidate_start "$op_id" "$target_digest" "$db_name" >/dev/null
    # Copy filestore into bind mount already used; DB clone is logical via separate PG db name
    SOVIEZ_OP="$op_id" SOVIEZ_C="soviez-upd-cand-${op_id}" SOVIEZ_N="soviez-upd-net-${op_id}" SOVIEZ_D="$target_digest" \
    SOVIEZ_U="$db_uuid" SOVIEZ_T="$tenant_id" python3 - <<'PY' > "$cdir/candidate.json"
import json,os
print(json.dumps({
  "operation_id":os.environ["SOVIEZ_OP"],
  "container":os.environ["SOVIEZ_C"],
  "network":os.environ["SOVIEZ_N"],
  "target_digest":os.environ["SOVIEZ_D"],
  "database_uuid":os.environ["SOVIEZ_U"],
  "production_tenant_id":os.environ["SOVIEZ_T"],
  "license_slot_consumed":False,
  "temporary":True,
  "role":"update_candidate",
  "neutralized":True,
  "real_docker":True,
},separators=(",",":")))
PY
    if declare -F soviez_update_lg_identity_write >/dev/null 2>&1; then
      soviez_update_lg_identity_write "$op_id" "$prod_json" "$target_digest" >/dev/null
    fi
    cat "$cdir/candidate.json"
    return 0
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mkdir -p "$SOVIEZ_ROOT/stubs"
    printf 'container=%s\nimage_digest=%s\n' "$container_name" "$target_digest" \
      > "$SOVIEZ_ROOT/stubs/candidate-${op_id}.started"
  else
    docker network create "$network_name" >/dev/null 2>&1 || true
    docker run -d --name "$container_name" --network "$network_name" \
      -e SOVIEZ_CANDIDATE=1 -e SOVIEZ_MAIL_DISABLED=1 \
      "soviez/erp@$target_digest" sleep infinity >/dev/null 2>&1 \
      || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate container start failed"
  fi

  SOVIEZ_OP="$op_id" SOVIEZ_C="$container_name" SOVIEZ_N="$network_name" SOVIEZ_D="$target_digest" \
  SOVIEZ_U="$db_uuid" SOVIEZ_T="$tenant_id" python3 - <<'PY' > "$cdir/candidate.json"
import json,os
print(json.dumps({
  "operation_id":os.environ["SOVIEZ_OP"],
  "container":os.environ["SOVIEZ_C"],
  "network":os.environ["SOVIEZ_N"],
  "target_digest":os.environ["SOVIEZ_D"],
  "database_uuid":os.environ["SOVIEZ_U"],
  "production_tenant_id":os.environ["SOVIEZ_T"],
  "license_slot_consumed":False,
  "temporary":True,
  "role":"update_candidate",
  "neutralized":True,
},separators=(",",":")))
PY
  if declare -F soviez_update_lg_identity_write >/dev/null 2>&1; then
    soviez_update_lg_identity_write "$op_id" "$prod_json" "$target_digest" >/dev/null
  fi
  cat "$cdir/candidate.json"
}

soviez_update_candidate_cleanup() {
  local op_id="$1"
  local cdir container network
  cdir="$(soviez_update_candidate_dir "$op_id")"
  [[ -d "$cdir" ]] || return 0
  container="$(awk -F= '/^container=/{print $2}' "$cdir/runtime/identity.txt" 2>/dev/null || true)"
  network="$(awk -F= '/^network=/{print $2}' "$cdir/runtime/identity.txt" 2>/dev/null || true)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]] || soviez_update_real_docker_enabled 2>/dev/null; then
    if declare -F soviez_update_docker >/dev/null 2>&1; then
      [[ -n "$container" ]] && soviez_update_docker rm -f "$container" >/dev/null 2>&1 || true
      [[ -n "$network" ]] && soviez_update_docker network rm "$network" >/dev/null 2>&1 || true
    else
      [[ -n "$container" ]] && docker rm -f "$container" >/dev/null 2>&1 || true
      [[ -n "$network" ]] && docker network rm "$network" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -f "$cdir/runtime/license_guard_identity.json" ]]; then
    SOVIEZ_ID="$(cat "$cdir/runtime/license_guard_identity.json")" python3 - <<'PY' > "$cdir/runtime/license_guard_identity.json.tmp" 2>/dev/null || true
import json,os
d=json.loads(os.environ["SOVIEZ_ID"]); d["cleanup_state"]="cleaned"; print(json.dumps(d,separators=(",",":")))
PY
    mv "$cdir/runtime/license_guard_identity.json.tmp" "$cdir/runtime/license_guard_identity.json" 2>/dev/null || true
  fi
  rm -rf "$cdir"
}
