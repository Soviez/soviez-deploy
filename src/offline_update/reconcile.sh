# shellcheck shell=bash
# Explicit later reconciliation — never disables ERP.

soviez_offline_reconcile_receipt() {
  local receipt="$1"
  local expected_license="${2:-}"
  local expected_env="${3:-}"
  [[ -f "$receipt" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_FOUND "$receipt"
  soviez_offline_trust_verify_json_file result_receipt "$receipt" || \
    soviez_offline_die OFFLINE_BUNDLE_SIGNATURE_INVALID "Forged or unsigned receipt"
  local body lic env rid
  body="$(cat "$receipt")"
  lic="$(soviez_json_get "$body" license_id)"
  env="$(soviez_json_get "$body" environment_id)"
  rid="$(soviez_json_get "$body" receipt_id)"
  if [[ -n "$expected_license" && "$lic" != "$expected_license" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_LICENSE_MISMATCH "Receipt license mismatch"
  fi
  if [[ -n "$expected_env" && "$env" != "$expected_env" ]]; then
    soviez_offline_die OFFLINE_BUNDLE_ENVIRONMENT_MISMATCH "Receipt environment mismatch"
  fi
  soviez_offline_bundle_paths_init
  local ledger="$SOVIEZ_OFFLINE_BUNDLE_ROOT/reconciliation_ledger.json"
  [[ -f "$ledger" ]] || printf '{"schema":"soviez.offline_reconcile.v1","receipts":{}}\n' > "$ledger"
  SOVIEZ_L="$ledger" SOVIEZ_R="$rid" SOVIEZ_B="$body" python3 - <<'PY'
import json, os, datetime
p=os.environ["SOVIEZ_L"]
d=json.load(open(p))
rid=os.environ["SOVIEZ_R"]
body=json.loads(os.environ["SOVIEZ_B"])
if rid in d.get("receipts",{}):
  # idempotent
  print(json.dumps({"ok":True,"idempotent":True,"receipt_id":rid}))
else:
  d.setdefault("receipts",{})[rid]={
    "imported_at":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "result":body.get("result"),
    "bundle_id":body.get("bundle_id"),
    "license_id":body.get("license_id"),
    "environment_id":body.get("environment_id"),
  }
  open(p,"w").write(json.dumps(d,indent=2,sort_keys=True)+"\n")
  print(json.dumps({"ok":True,"idempotent":False,"receipt_id":rid}))
PY
  echo "RECONCILIATION — RECORDED (ERP not affected)"
}
