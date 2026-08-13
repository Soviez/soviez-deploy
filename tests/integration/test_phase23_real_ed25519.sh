#!/usr/bin/env bash
# Phase 23 — real Ed25519 signing/verification proof + tamper rejection.
# Directly closes F17 in PRIOR_FAILURE_LEDGER.md (run-A "Algorithm ED25519
# not found" cascade caused by resolving macOS's bundled LibreSSL instead of
# a real OpenSSL 3.x build). No stubbed/fixture signatures anywhere in this
# test — every signature is produced and verified by real `openssl
# pkeyutl` calls against the pinned $SOVIEZ_OPENSSL binary.
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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-ed25519.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust"
trap 'rm -rf "$TMP"' EXIT

echo "== pinned OpenSSL is a real OpenSSL 3.x build (not LibreSSL) =="
OSSL_BIN="$(soviez_offline_openssl)"
echo "resolved SOVIEZ_OPENSSL binary: $OSSL_BIN"
[[ "$OSSL_BIN" == "$SOVIEZ_OPENSSL" ]] || { echo "FAIL: resolver did not honor pinned SOVIEZ_OPENSSL=$SOVIEZ_OPENSSL (got $OSSL_BIN)"; exit 1; }
ver="$("$OSSL_BIN" version)"
echo "$ver"
[[ "$ver" == OpenSSL\ 3.* ]] || { echo "FAIL: pinned OpenSSL is not a 3.x build: $ver"; exit 1; }
[[ "$ver" != *LibreSSL* ]] || { echo "FAIL: pinned OpenSSL resolved to LibreSSL (this is exactly the run-A F17 regression)"; exit 1; }

echo "== real Ed25519 keypair generation (purpose: bundle_manifest) =="
soviez_offline_trust_ensure_purpose_keypair bundle_manifest
priv="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/bundle_manifest.key"
pub="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/bundle_manifest.pub"
[[ -f "$priv" ]] || { echo "FAIL: private key not created"; exit 1; }
[[ -f "$pub" ]] || { echo "FAIL: public key not created"; exit 1; }
grep -q 'BEGIN PRIVATE KEY' "$priv" || { echo "FAIL: private key is not real PEM"; exit 1; }
grep -q 'BEGIN PUBLIC KEY' "$pub" || { echo "FAIL: public key is not real PEM"; exit 1; }
keytext="$("$OSSL_BIN" pkey -in "$priv" -text -noout 2>/dev/null || true)"
printf '%s\n' "$keytext" | grep -qi 'ED25519' || { echo "FAIL: generated key is not ED25519 (got: $keytext)"; exit 1; }
echo "[assert] real PEM keypair generated, algorithm confirmed ED25519"

echo "== real sign + verify round-trip =="
PAYLOAD='{"schema":"soviez.phase23.ed25519_proof.v1","bundle_id":"bun-ed25519-proof","nonce":"'"$$"'"}'
SIG="$(soviez_offline_trust_sign_payload bundle_manifest "$PAYLOAD")"
[[ -n "$SIG" ]] || { echo "FAIL: empty signature"; exit 1; }
echo "signature (b64url): $SIG"

# Ed25519 signatures are exactly 64 raw bytes. Decode and measure to prove
# this is a real signature, not a fixture string like "ok"/"valid".
pad=$(( (4 - ${#SIG} % 4) % 4 ))
padded="$SIG"
i=0
while [[ $i -lt $pad ]]; do padded="${padded}="; i=$((i + 1)); done
sigbin="$TMP/sig.bin"
printf '%s' "$padded" | tr '_-' '/+' | "$OSSL_BIN" base64 -d -A -out "$sigbin"
siglen="$(wc -c < "$sigbin" | tr -d ' ')"
[[ "$siglen" == "64" ]] || { echo "FAIL: decoded signature is $siglen bytes, expected exactly 64 (real Ed25519 signature length)"; exit 1; }
echo "[assert] decoded signature is exactly 64 raw bytes"

soviez_offline_trust_verify_payload bundle_manifest "$PAYLOAD" "$SIG" || { echo "FAIL: valid signature rejected"; exit 1; }
echo "[assert] valid signature verified"

echo "== tamper reject: mutated payload =="
set +e
soviez_offline_trust_verify_payload bundle_manifest "${PAYLOAD}TAMPERED" "$SIG"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: tampered payload was accepted"; exit 1; }
echo "[assert] tampered payload rejected rc=$rc"

echo "== tamper reject: mutated signature (bit-flip in decoded bytes) =="
# Flipping only the final base64url character can leave the decoded 64-byte
# signature unchanged (padding/unused bits). Corrupt a middle decoded byte instead.
TAMPERED_SIG="$(
  SIG_B64URL="$SIG" python3 - <<'PY'
import os, base64
s = os.environ["SIG_B64URL"]
pad = "=" * ((4 - len(s) % 4) % 4)
raw = bytearray(base64.urlsafe_b64decode(s + pad))
assert len(raw) == 64, len(raw)
raw[16] ^= 0xFF
print(base64.urlsafe_b64encode(bytes(raw)).decode().rstrip("="))
PY
)"
[[ "$TAMPERED_SIG" != "$SIG" ]] || { echo "FAIL: tamper helper produced identical signature"; exit 1; }
set +e
soviez_offline_trust_verify_payload bundle_manifest "$PAYLOAD" "$TAMPERED_SIG"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: tampered signature was accepted"; exit 1; }
echo "[assert] tampered signature rejected rc=$rc"

echo "== purpose separation: wrong-purpose public key rejects correct signature =="
soviez_offline_trust_ensure_purpose_keypair release
release_pub="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/release.pub"
set +e
soviez_offline_trust_verify_payload bundle_manifest "$PAYLOAD" "$SIG" "$release_pub"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: signature verified against wrong-purpose public key"; exit 1; }
echo "[assert] cross-purpose verification rejected rc=$rc"

echo "== end-to-end signed JSON file round-trip + tamper-after-sign reject =="
docf="$TMP/doc.json"
printf '{"schema":"soviez.phase23.doc.v1","bundle_id":"bun-doc-1","amount":100}' > "$docf"
soviez_offline_trust_sign_json_file bundle_manifest "$docf"
grep -q signature_b64url "$docf" || { echo "FAIL: signed JSON file missing signature_b64url"; exit 1; }
soviez_offline_trust_verify_json_file bundle_manifest "$docf" || { echo "FAIL: freshly signed JSON file failed verification"; exit 1; }
echo "[assert] signed JSON file verifies"

python3 - "$docf" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["amount"] = 999999
json.dump(d, open(p, "w"))
PY
set +e
soviez_offline_trust_verify_json_file bundle_manifest "$docf"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: JSON file tampered after signing still verified"; exit 1; }
echo "[assert] JSON file tampered post-signature rejected rc=$rc"

echo "== certification mode forbids fixture/fake signature strings outright =="
fixture_doc="$TMP/fixture.json"
printf '{"schema":"soviez.phase23.doc.v1","bundle_id":"bun-fixture-1","signature_b64url":"ok"}' > "$fixture_doc"
set +e
soviez_offline_trust_verify_json_file bundle_manifest "$fixture_doc"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: fixture signature string 'ok' was accepted under SOVIEZ_PHASE23_CERTIFICATION=1"; exit 1; }
echo "[assert] fixture signature string rejected under certification mode rc=$rc"

echo "OK test_phase23_real_ed25519"
exit 0
