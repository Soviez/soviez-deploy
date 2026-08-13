# shellcheck shell=bash

soviez_update_switch() {
  local op_id="$1" prod_json="$2" target_digest="$3"
  local tenant_id previous_digest switch_start switch_end downtime_ms
  tenant_id="$(soviez_json_get "$prod_json" tenant_id)"
  previous_digest="$(soviez_json_get "$prod_json" current_digest 2>/dev/null || soviez_json_get "$prod_json" image_digest 2>/dev/null || echo unknown)"

  if [[ "${SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL:-0}" == "1" ]]; then
    soviez_update_die UPDATE_SWITCH_FAILED "Injected switch/routing failure"
  fi

  switch_start="$(date +%s 2>/dev/null || echo 0)"
  # Preserve previous runtime for rollback — do not delete old Production
  local runtime_dir="${SOVIEZ_TENANT_DIR:-$SOVIEZ_ROOT/tenant}/$tenant_id"
  mkdir -p "$runtime_dir"
  printf '%s' "$previous_digest" > "$runtime_dir/previous_digest.txt"
  printf '%s' "$target_digest" > "$runtime_dir/current_digest.txt"
  # Update identity digest fields without mutating other tenants
  if [[ -f "$runtime_dir/identity.json" ]]; then
    SOVIEZ_ID="$(cat "$runtime_dir/identity.json")" SOVIEZ_D="$target_digest" python3 - <<'PY' > "$runtime_dir/identity.json.tmp"
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
d["previous_digest"]=d.get("current_digest") or d.get("image_digest")
d["current_digest"]=os.environ["SOVIEZ_D"]
d["image_digest"]=os.environ["SOVIEZ_D"]
print(json.dumps(d,separators=(",",":")))
PY
    mv "$runtime_dir/identity.json.tmp" "$runtime_dir/identity.json"
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mkdir -p "$SOVIEZ_ROOT/stubs"
    printf 'switched_tenant=%s\ndigest=%s\n' "$tenant_id" "$target_digest" \
      > "$SOVIEZ_ROOT/stubs/switch-${op_id}.done"
  else
    # Near-atomic: stop old, retarget nginx to candidate-promoted container, start new
    local prod_container
    prod_container="$(soviez_json_get "$prod_json" container 2>/dev/null || echo "soviez-web-$tenant_id")"
    docker rename "$prod_container" "${prod_container}-prev" >/dev/null 2>&1 || true
    docker rename "soviez-upd-cand-${op_id}" "$prod_container" >/dev/null 2>&1 \
      || soviez_update_die UPDATE_SWITCH_FAILED "Container cutover failed"
  fi
  switch_end="$(date +%s 2>/dev/null || echo 0)"
  downtime_ms=$(( (switch_end - switch_start) * 1000 ))
  [[ "$downtime_ms" -ge 0 ]] || downtime_ms=0

  if [[ "${SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL:-0}" == "1" ]]; then
    SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_PD="$previous_digest" SOVIEZ_TD="$target_digest" \
    SOVIEZ_DT="$downtime_ms" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/switch.json"
import json,os
print(json.dumps({
  "ok":False,
  "tenant_id":os.environ["SOVIEZ_T"],
  "previous_digest":os.environ["SOVIEZ_PD"],
  "current_digest":os.environ["SOVIEZ_TD"],
  "downtime_ms":int(os.environ["SOVIEZ_DT"]),
  "post_switch":"login_failed",
},separators=(",",":")))
PY
    soviez_update_die UPDATE_POST_SWITCH_VALIDATION_FAILED "Post-switch login/health failed"
  fi

  SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_PD="$previous_digest" SOVIEZ_TD="$target_digest" \
  SOVIEZ_DT="$downtime_ms" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/switch.json"
import json,os
print(json.dumps({
  "ok":True,
  "tenant_id":os.environ["SOVIEZ_T"],
  "previous_digest":os.environ["SOVIEZ_PD"],
  "current_digest":os.environ["SOVIEZ_TD"],
  "downtime_ms":int(os.environ["SOVIEZ_DT"]),
  "unrelated_tenants_mutated":False,
},separators=(",",":")))
PY
  cat "$(soviez_update_op_dir "$op_id")/switch.json"
}
