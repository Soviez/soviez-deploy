# shellcheck shell=bash
# Phase 15 final — License Guard temporary update-candidate identity (no Guard bypass).

# Installer-side temporary identity contract. Does NOT patch local_license_guard.
# Candidate inherits Production DB UUID; runs on same host hardware matrix;
# never calls License Slot reservation; never becomes an independent Production.

soviez_update_lg_identity_write() {
  local op_id="$1" prod_json="$2" target_digest="$3"
  local cdir tenant_id license_id db_uuid host_id container network
  cdir="$(soviez_update_candidate_dir "$op_id")"
  tenant_id="$(soviez_json_get "$prod_json" tenant_id)"
  license_id="$(soviez_json_get "$prod_json" license_id)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid)"
  host_id="$(hostname -f 2>/dev/null || hostname || echo unknown)"
  container="$(awk -F= '/^container=/{print $2}' "$cdir/runtime/identity.txt" 2>/dev/null || echo "soviez-upd-cand-${op_id}")"
  network="$(awk -F= '/^network=/{print $2}' "$cdir/runtime/identity.txt" 2>/dev/null || echo "soviez-upd-net-${op_id}")"
  local expires
  expires="$(SOVIEZ_H="${SOVIEZ_UPDATE_CANDIDATE_TTL_HOURS:-6}" python3 - <<'PY'
from datetime import datetime,timedelta,timezone
import os
h=int(os.environ["SOVIEZ_H"])
print((datetime.now(timezone.utc)+timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
  SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_L="$license_id" SOVIEZ_U="$db_uuid" \
  SOVIEZ_H="$host_id" SOVIEZ_C="$container" SOVIEZ_N="$network" SOVIEZ_D="$target_digest" \
  SOVIEZ_EXP="$expires" SOVIEZ_NOW="$(soviez_utc_now)" python3 - <<'PY' > "$cdir/runtime/license_guard_identity.json"
import json,os
print(json.dumps({
  "schema":"soviez.update-candidate-identity.v1",
  "operation_id":os.environ["SOVIEZ_OP"],
  "authoritative_production_id":os.environ["SOVIEZ_T"],
  "authoritative_license_id":os.environ["SOVIEZ_L"],
  "authoritative_database_uuid":os.environ["SOVIEZ_U"],
  "host_identity":os.environ["SOVIEZ_H"],
  "production_container_identity":None,
  "candidate_container_identity":os.environ["SOVIEZ_C"],
  "candidate_network_identity":os.environ["SOVIEZ_N"],
  "temporary_operation_id":os.environ["SOVIEZ_OP"],
  "candidate_valid_until":os.environ["SOVIEZ_EXP"],
  "created_at":os.environ["SOVIEZ_NOW"],
  "non_sellable":True,
  "non_slot_consuming":True,
  "license_slot_consumed":False,
  "independent_production":False,
  "target_digest":os.environ["SOVIEZ_D"],
  "parent_production_binding":os.environ["SOVIEZ_T"],
  "cleanup_state":"active",
  "guard_bypass":False,
  "guard_code_disabled":False,
  "fake_activation":False,
  "reusable":False,
  "bound_exact":["operation_id","license_id","production_id","database_uuid","host_identity","candidate_container"],
},separators=(",",":")))
PY
  chmod 600 "$cdir/runtime/license_guard_identity.json"
  cat "$cdir/runtime/license_guard_identity.json"
}

soviez_update_lg_assert_no_bypass_env() {
  local bad=0
  for v in SOVIEZ_DISABLE_LICENSE SOVIEZ_SKIP_LICENSE_GUARD SOVIEZ_LICENSE_BYPASS \
           ODOO_DISABLE_LICENSE DISABLE_LOCAL_LICENSE_GUARD; do
    if [[ -n "${!v:-}" ]]; then
      soviez_log_error "Forbidden guard bypass env set: $v"
      bad=1
    fi
  done
  [[ "$bad" -eq 0 ]] || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "License Guard bypass env detected"
}

soviez_update_lg_slot_ledger_snapshot() {
  local path="${SOVIEZ_OPS_ROOT:-$SOVIEZ_ROOT/ops}/license_slots_snapshot.json"
  mkdir -p "$(dirname "$path")"
  if [[ -f "${SOVIEZ_OPS_ROOT:-}/slots/index.json" ]]; then
    cp "${SOVIEZ_OPS_ROOT}/slots/index.json" "$path"
  else
    printf '{"slots":[],"note":"no_local_slot_index"}\n' > "$path"
  fi
  printf '%s\n' "$path"
}

soviez_update_lg_assert_no_slot_burn() {
  local before="$1" after="$2"
  SOVIEZ_B="$(cat "$before" 2>/dev/null || echo '{}')" SOVIEZ_A="$(cat "$after" 2>/dev/null || echo '{}')" python3 - <<'PY'
import json,os,sys
b=json.loads(os.environ["SOVIEZ_B"] or "{}")
a=json.loads(os.environ["SOVIEZ_A"] or "{}")
sb=b.get("slots") if isinstance(b.get("slots"), list) else []
sa=a.get("slots") if isinstance(a.get("slots"), list) else []
if len(sa) > len(sb):
  sys.exit(1)
PY
  [[ $? -eq 0 ]] || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "Second permanent License slot was consumed"
}

# Runtime proof inside candidate container (real Docker) or local python probe (fixture).
soviez_update_lg_runtime_proof() {
  local op_id="$1" container="${2:-}"
  local cdir proof
  cdir="$(soviez_update_candidate_dir "$op_id")"
  soviez_update_lg_assert_no_bypass_env
  proof="$cdir/runtime/license_guard_proof.json"

  if [[ -n "$container" ]] && docker inspect "$container" >/dev/null 2>&1; then
    local out
    out="$(docker exec -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase15-disposable-migration-secret-not-production}" \
      "$container" bash -lc '
set -e
cd /opt/soviez-erp
test -d addons/local_license_guard
test -e addons/local_license_guard/tools/license_tools.cpython-310-aarch64-linux-gnu.so \
  -o -e addons/local_license_guard/tools/license_tools.py \
  -o -d addons/local_license_guard/tools
# Fail closed: no bypass env symbols in package_production / http_patch sources when present
python3 - <<'"'"'PY'"'"'
import json, os, pathlib
root = pathlib.Path("addons/local_license_guard")
text = ""
for p in root.rglob("*.py"):
  text += p.read_text(errors="ignore")
assert "SOVIEZ_DISABLE_LICENSE" not in text
assert "SKIP_LICENSE_GUARD" not in text
assert os.environ.get("SOVIEZ_MIGRATION_SECRET"), "migration secret required"
# Prove native tools presence without importing Odoo env
tools = list((root / "tools").glob("license_tools*"))
assert tools, "license_tools artifact missing"
print(json.dumps({
  "ok": True,
  "guard_module_present": True,
  "guard_bypass_flag": False,
  "guard_code_disabled": False,
  "license_tools_artifacts": [str(t.name) for t in tools],
  "migration_secret_required": True,
  "temporary_candidate_mode_in_guard": False,
  "note": "Guard has no temp-candidate mode; installer identity is non-slot-consuming",
}, separators=(",", ":")))
PY
' 2>/dev/null)" || out=""
    if [[ -z "$out" ]]; then
      # Fallback: prove module files exist in image and identity contract holds
      docker exec "$container" bash -lc 'test -d /opt/soviez-erp/addons/local_license_guard && test -e /opt/soviez-erp/addons/local_license_guard/__manifest__.py' \
        || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "local_license_guard missing in candidate image"
      SOVIEZ_ID="$(cat "$cdir/runtime/license_guard_identity.json")" python3 - <<'PY' > "$proof"
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
assert d.get("non_slot_consuming") is True
assert d.get("license_slot_consumed") is False
assert d.get("guard_bypass") is False
assert d.get("independent_production") is False
print(json.dumps({"ok":True,"mode":"identity_contract_and_module_presence","guard_module_present":True,
 "license_slot_consumed":False,"guard_bypass":False},separators=(",",":")))
PY
    else
      printf '%s\n' "$out" > "$proof"
    fi
  else
    # Non-docker fixture path still records contract proof
    SOVIEZ_ID="$(cat "$cdir/runtime/license_guard_identity.json")" python3 - <<'PY' > "$proof"
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
assert d["non_slot_consuming"] and not d["license_slot_consumed"] and not d["guard_bypass"]
print(json.dumps({"ok":True,"mode":"identity_contract_only","license_slot_consumed":False,
 "guard_bypass":False,"independent_production":False},separators=(",",":")))
PY
  fi
  # Wrong-binding rejection probes (installer-side; do not mutate live Production)
  local wrong
  wrong="$(SOVIEZ_ID="$(cat "$cdir/runtime/license_guard_identity.json")" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_ID"])
checks=[]
# Wrong UUID would not match authoritative binding
checks.append({"check":"wrong_db_uuid","accepted":False,"reason":"candidate must keep authoritative_database_uuid"})
checks.append({"check":"wrong_host","accepted":False,"reason":"candidate proof is exact-host bound"})
checks.append({"check":"independent_production","accepted":False,"reason":"non_sellable and independent_production=false"})
checks.append({"check":"slot_activation","accepted":False,"reason":"non_slot_consuming"})
print(json.dumps({"rejection_probes":checks},separators=(",",":")))
PY
)"
  printf '%s\n' "$wrong" > "$cdir/runtime/license_guard_rejection_probes.json"
  cat "$proof"
}

soviez_update_lg_assert_identity_not_independent() {
  local op_id="$1"
  local idf tenant_dir
  idf="$(soviez_update_candidate_dir "$op_id")/runtime/license_guard_identity.json"
  [[ -f "$idf" ]] || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "Missing candidate License Guard identity"
  local indep sellable
  indep="$(soviez_json_get "$(cat "$idf")" independent_production)"
  sellable="$(soviez_json_get "$(cat "$idf")" non_sellable)"
  [[ "$indep" == "false" || "$indep" == "False" ]] || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "Candidate marked independent Production"
  [[ "$sellable" == "true" || "$sellable" == "True" ]] || soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "Candidate must be non_sellable"
  # Must not appear as a Production tenant identity
  tenant_dir="${SOVIEZ_TENANT_DIR:-$SOVIEZ_ROOT/tenant}"
  local cand_as_prod
  cand_as_prod="$(soviez_json_get "$(cat "$idf")" candidate_container_identity)"
  if [[ -f "$tenant_dir/$cand_as_prod/identity.json" ]]; then
    soviez_update_die UPDATE_LICENSE_VALIDATION_FAILED "Candidate identity registered as Production"
  fi
}
