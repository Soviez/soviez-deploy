#!/usr/bin/env bash
# Phase 23 unit: Ed25519 sign/verify, entitlement gate, fake signature rejection
set -euo pipefail
# Disable pipefail for this suite — macOS find/tar/zstd pipelines are SIGPIPE-noisy.
set +o pipefail
trap 'echo "[phase23-unit] EXIT status=$? at line $LINENO" >&2' EXIT
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"
[[ -x "$SOVIEZ_OPENSSL" ]] || export SOVIEZ_OPENSSL="$(command -v openssl)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-unit.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_PHASE23_CERTIFICATION=1
export SOVIEZ_PHASE23_REQUIRE_REAL_ED25519=1
export SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES=1
mkdir -p "$SOVIEZ_ROOT"

# Source assembled functions via extracting modules OR run via bash -c with dist
# Prefer sourcing modular files for unit speed
# shellcheck disable=SC1091
source src/offline_trust/keys.sh
# shellcheck disable=SC1091
source src/offline_bundle/codes.sh
# shellcheck disable=SC1091
source src/offline_bundle/paths.sh
# shellcheck disable=SC1091
source src/offline_bundle/entitlement.sh
# shellcheck disable=SC1091
source src/offline_bundle/package.sh
# shellcheck disable=SC1091
source src/offline_bundle/replay.sh
# shellcheck disable=SC1091
source src/offline_bundle/import.sh
# shellcheck disable=SC1091
source src/offline_bundle/cert_gates.sh
# shellcheck disable=SC1091
source src/offline_update/apply.sh
# shellcheck disable=SC1091
source src/offline_update/reconcile.sh

# Need soviez_json_get / soviez_paths_init
if ! declare -F soviez_json_get >/dev/null 2>&1; then
  soviez_json_get() {
    local json="$1" key="$2"
    SOVIEZ_J="$json" SOVIEZ_K="$key" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_J"])
k=os.environ["SOVIEZ_K"]
v=d
for p in k.split("."):
  if isinstance(v,dict) and p in v: v=v[p]
  else: print(""); raise SystemExit(0)
print(v if not isinstance(v,(dict,list)) else json.dumps(v))
PY
  }
fi
if ! declare -F soviez_paths_init >/dev/null 2>&1; then
  soviez_paths_init() { :; }
fi

echo "== Ed25519 purpose sign/verify =="
soviez_offline_trust_ensure_purpose_keypair authorization
payload='{"a":1,"b":"test"}'
sig="$(soviez_offline_trust_sign_payload authorization "$payload")"
soviez_offline_trust_verify_payload authorization "$payload" "$sig"
! soviez_offline_trust_verify_payload authorization "${payload}x" "$sig"

echo "== entitlement gate =="
ok="$(soviez_offline_entitlement_fixture_ok lic-1)"
soviez_offline_entitlement_require "$ok" lic-1
set +e
SOVIEZ_OFFLINE_SOFT_DIE=1 soviez_offline_entitlement_require '{"status":"active","capabilities":["product_updates"],"license_id":"lic-1"}' lic-1
rc=$?
unset SOVIEZ_OFFLINE_SOFT_DIE
set -e
[[ $rc -ne 0 ]]

echo "== issue + inspect + import + replay apply once =="
export SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust"
export SOVIEZ_OFFLINE_BUNDLE_ROOT="$TMP/bundles"
lic=lic-A; env=env-A; dev=dev-fp-A
digest="sha256:$(printf 'layer' | shasum -a 256 | awk '{print $1}')"
archive="$(soviez_offline_bundle_issue_local "bun-1" "$lic" "$env" "$dev" "$digest" "$digest")"
[[ -f "$archive" ]]
insp="$(soviez_offline_bundle_inspect "$archive")"
printf '%s\n' "$insp" | grep -q 'SIGNATURE — VALID'
manifest="$(soviez_offline_bundle_import "$archive" "$lic" "$env" "$dev" "$digest")"
printf '%s\n' "$manifest" | grep -q phase23_bundle

export SOVIEZ_LICENSE_ID="$lic" SOVIEZ_ENVIRONMENT_ID="$env" SOVIEZ_DEVICE_FINGERPRINT="$dev"
export SOVIEZ_OFFLINE_APPLY_YES=1
apply_out="$(soviez_offline_update_apply "$archive")"
printf '%s\n' "$apply_out" > "$TMP/apply.out"
grep -q 'RESULT RECEIPT — SIGNED' "$TMP/apply.out"
grep -q 'ERP RUNTIME — INDEPENDENT' "$TMP/apply.out"

set +e
SOVIEZ_OFFLINE_SOFT_DIE=1 soviez_offline_update_apply "bun-1" >/dev/null 2>&1
rc=$?
unset SOVIEZ_OFFLINE_SOFT_DIE
set -e
[[ $rc -ne 0 ]]

echo "== wrong device denied =="
set +e
SOVIEZ_OFFLINE_SOFT_DIE=1 soviez_offline_bundle_import "$archive" "$lic" "$env" "wrong-device" "$digest" >/dev/null 2>&1
rc=$?
unset SOVIEZ_OFFLINE_SOFT_DIE
set -e
[[ $rc -ne 0 ]]

echo "== fake signature rejected in cert mode =="
printf '{"schema_version":"x","signature_b64url":"ok"}\n' > "$TMP/fake.json"
set +e
soviez_offline_trust_verify_json_file authorization "$TMP/fake.json"
rc=$?
set -e
[[ $rc -ne 0 ]]

echo "== reconcile does not disable ERP =="
op="$(grep OPERATION_ID= "$TMP/apply.out" | cut -d= -f2)"
receipt="$(grep RECEIPT= "$TMP/apply.out" | cut -d= -f2)"
soviez_offline_reconcile_receipt "$receipt" "$lic" "$env"
soviez_offline_reconcile_receipt "$receipt" "$lic" "$env"  # idempotent

echo "OK test_phase23_offline_bundle_unit"
rm -rf "$TMP"
trap - EXIT
exit 0
