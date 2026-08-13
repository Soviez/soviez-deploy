#!/usr/bin/env bash
# Phase 23 — real air-gapped offline apply proof: network actively denied
# during apply (proxy black-holed + live network probe fails), a signed
# result receipt is produced, and the receipt's own network-proof artifact
# records network_required_during_apply=false.
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env
soviez_phase23_assert_cert_gates

bash build/assemble.sh >/dev/null
source src/offline_trust/keys.sh
source src/offline_bundle/codes.sh
source src/offline_bundle/paths.sh
source src/offline_bundle/entitlement.sh
source src/offline_bundle/package.sh
source src/offline_bundle/replay.sh
source src/offline_bundle/import.sh
source src/offline_bundle/cert_gates.sh
source src/offline_update/apply.sh

soviez_json_get() {
  SOVIEZ_J="$1" SOVIEZ_K="$2" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_J"]); k=os.environ["SOVIEZ_K"]; v=d
for p in k.split("."):
  if isinstance(v,dict) and p in v: v=v[p]
  else: print(""); raise SystemExit(0)
print(v if not isinstance(v,(dict,list)) else json.dumps(v))
PY
}
soviez_paths_init() { :; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-airgap.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1
export SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust"
export SOVIEZ_OFFLINE_BUNDLE_ROOT="$TMP/bundles"
trap 'rm -rf "$TMP"' EXIT

echo "== issue + import offline bundle =="
d1="sha256:$(printf 'p23-airgap' | shasum -a 256 | awk '{print $1}')"
BID="bun-airgap-$$"
ARCH="$(soviez_offline_bundle_issue_local "$BID" lic-airgap env-airgap fp-airgap "$d1" "$d1")"
soviez_offline_bundle_import "$ARCH" lic-airgap env-airgap fp-airgap "$d1" >/dev/null

export SOVIEZ_LICENSE_ID=lic-airgap SOVIEZ_ENVIRONMENT_ID=env-airgap SOVIEZ_DEVICE_FINGERPRINT=fp-airgap
export SOVIEZ_OFFLINE_APPLY_YES=1

echo "== proxy env is clean before apply =="
unset http_proxy https_proxy NO_PROXY no_proxy SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED 2>/dev/null || true
[[ -z "${http_proxy:-}" ]] || { echo "FAIL: http_proxy pre-set before apply invalidates the proof"; exit 1; }

echo "== soviez_offline_update_plan (real, matches CLI offline-update-plan path) =="
plan_out="$(soviez_offline_update_plan "$ARCH")"
printf '%s\n' "$plan_out" | grep -q 'NETWORK REQUIRED DURING APPLY — NO' || { echo "FAIL: plan missing NETWORK REQUIRED DURING APPLY — NO"; exit 1; }
echo "[assert] plan declares no network required during apply"

echo "== soviez_offline_update_apply (real, no network reachable) =="
# Run as a plain command (not $(...) command substitution) so the exports
# soviez_phase23_assert_no_network_hooks makes (http_proxy/https_proxy
# black-hole, SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED) survive in THIS shell
# and can be inspected/proved below — a subshell would silently discard them.
soviez_offline_update_apply "$ARCH" > "$TMP/apply_out.txt"
apply_out="$(cat "$TMP/apply_out.txt")"
printf '%s\n' "$apply_out"

echo "== assert apply banners present =="
printf '%s\n' "$apply_out" | grep -q 'RESULT RECEIPT — SIGNED' || { echo "FAIL: apply missing RESULT RECEIPT — SIGNED"; exit 1; }
printf '%s\n' "$apply_out" | grep -q '^OPERATION_ID=' || { echo "FAIL: apply missing OPERATION_ID"; exit 1; }
printf '%s\n' "$apply_out" | grep -q '^RECEIPT=' || { echo "FAIL: apply missing RECEIPT path"; exit 1; }

echo "== network was actively denied during apply (proxy black-holed) =="
[[ "${SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED:-0}" == "1" ]] || { echo "FAIL: SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED not set by apply"; exit 1; }
[[ "${http_proxy:-}" == "http://127.0.0.1:1" ]] || { echo "FAIL: http_proxy not set to black-hole target (got '${http_proxy:-}')"; exit 1; }
[[ "${https_proxy:-}" == "http://127.0.0.1:1" ]] || { echo "FAIL: https_proxy not set to black-hole target"; exit 1; }
echo "[assert] apply left the process env in a network-denied state"

echo "== live network probe against the apply-time proxy config actually fails =="
set +e
curl -sS --max-time 2 --proxy "$http_proxy" http://169.254.169.254/ -o /dev/null
probe_rc=$?
set -e
[[ "$probe_rc" -ne 0 ]] || { echo "FAIL: outbound network probe SUCCEEDED through the apply-time proxy — air-gap not real"; exit 1; }
echo "[assert] live network probe denied (curl rc=$probe_rc) — this is a real network block, not just an env var"

OP_ID="$(printf '%s\n' "$apply_out" | grep '^OPERATION_ID=' | tail -1 | cut -d= -f2-)"
RECEIPT_PATH="$(printf '%s\n' "$apply_out" | grep '^RECEIPT=' | tail -1 | cut -d= -f2-)"
echo "OPERATION_ID=$OP_ID RECEIPT=$RECEIPT_PATH"

echo "== network_proof.txt records network_required_during_apply=false =="
OPDIR="$(soviez_offline_bundle_op_dir "$OP_ID")"
NETPROOF="$OPDIR/network_proof.txt"
[[ -f "$NETPROOF" ]] || { echo "FAIL: missing $NETPROOF"; exit 1; }
cat "$NETPROOF"
grep -qx 'network_required_during_apply=false' "$NETPROOF" || { echo "FAIL: network_proof.txt missing network_required_during_apply=false"; exit 1; }
grep -qx 'unexpected_network_attempts=0' "$NETPROOF" || { echo "FAIL: network_proof.txt missing unexpected_network_attempts=0"; exit 1; }
echo "[assert] network_proof.txt confirms no network dependency during apply"

echo "== result receipt is real, signed, and internally consistent =="
[[ -f "$RECEIPT_PATH" ]] || { echo "FAIL: receipt file missing at $RECEIPT_PATH"; exit 1; }
grep -q signature_b64url "$RECEIPT_PATH" || { echo "FAIL: receipt missing signature_b64url"; exit 1; }
soviez_offline_trust_verify_json_file result_receipt "$RECEIPT_PATH" || { echo "FAIL: receipt signature does not verify"; exit 1; }
receipt_json="$(cat "$RECEIPT_PATH")"
[[ "$(soviez_json_get "$receipt_json" bundle_id)" == "$BID" ]] || { echo "FAIL: receipt bundle_id mismatch"; exit 1; }
[[ "$(soviez_json_get "$receipt_json" result)" == "success" ]] || { echo "FAIL: receipt result != success"; exit 1; }
[[ "$(soviez_json_get "$receipt_json" operation_id)" == "$OP_ID" ]] || { echo "FAIL: receipt operation_id mismatch"; exit 1; }
echo "[assert] receipt cryptographically verified and internally consistent"

echo "== tamper the receipt post-hoc: verification must reject =="
python3 - "$RECEIPT_PATH" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["result"] = "tampered_success"
json.dump(d, open(p, "w"))
PY
set +e
soviez_offline_trust_verify_json_file result_receipt "$RECEIPT_PATH"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: tampered receipt still verified"; exit 1; }
echo "[assert] tampered receipt rejected rc=$rc"

echo "OK test_phase23_real_airgapped_apply"
exit 0
