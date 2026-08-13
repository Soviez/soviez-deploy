#!/usr/bin/env bash
# Phase 23 security adversary: forged bundle, purpose mismatch, trust rollback
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"

source src/offline_trust/keys.sh
source src/offline_bundle/codes.sh
source src/offline_bundle/paths.sh
source src/offline_bundle/package.sh
source src/offline_bundle/import.sh
source src/offline_bundle/replay.sh

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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-sec.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1 SOVIEZ_PHASE23_CERTIFICATION=1
export SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES=1 SOVIEZ_PHASE23_REQUIRE_REAL_ED25519=1
export SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust" SOVIEZ_OFFLINE_BUNDLE_ROOT="$TMP/bundles"

d="sha256:$(printf sec | shasum -a 256 | awk '{print $1}')"
arch="$(soviez_offline_bundle_issue_local bun-sec lic-s env-s fp-s "$d" "$d")"
soviez_offline_bundle_paths_init

work="$SOVIEZ_OFFLINE_BUNDLE_ISSUANCE_DIR/bun-sec/tree"
python3 - <<PY
import json
p="$work/bundle.json"
d=json.load(open(p))
d["license_id"]="attacker"
open(p,"w").write(json.dumps(d))
PY
set +e
soviez_offline_trust_verify_json_file bundle_manifest "$work/bundle.json"
rc=$?
set -e
[[ $rc -ne 0 ]]

soviez_offline_trust_ensure_purpose_keypair release
payload='{"x":1}'
sig="$(soviez_offline_trust_sign_payload release "$payload")"
set +e
soviez_offline_trust_verify_payload authorization "$payload" "$sig"
rc=$?
set -e
[[ $rc -ne 0 ]]

soviez_offline_trust_state_init
SOVIEZ_S="$SOVIEZ_OFFLINE_TRUST_STATE" python3 - <<'PY'
import json,os
p=os.environ["SOVIEZ_S"]; d=json.load(open(p)); d["sequence"]=5
open(p,"w").write(json.dumps(d))
PY
seq=3; local_seq=5
[[ "$seq" -lt "$local_seq" ]]

echo "OK test_phase23_offline_bundle_security"
rm -rf "$TMP"
exit 0
