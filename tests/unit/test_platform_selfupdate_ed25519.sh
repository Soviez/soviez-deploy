#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export SOVIEZ_OPENSSL=/opt/homebrew/bin/openssl
export SOVIEZ_TEST_MODE=1
export SOVIEZ_SKIP_PLATFORM_UPDATE=1
bash build/assemble.sh >/dev/null
# shellcheck disable=SC1091
source dist/soviez.sh
export SOVIEZ_PLATFORM_TRUST_DIR="$ROOT/share/platform-trust"
fail=0; ok=0
pass(){ echo PASS "$1"; ok=$((ok+1)); }
bad(){ echo FAIL "$1" >&2; fail=$((fail+1)); }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp platform-release/staging/manifest.json "$TMP/good.json"
cp dist/soviez.sh "$TMP/cand.sh"
soviez_platform_verify_candidate "$TMP/cand.sh" "$TMP/good.json" && pass GOOD || bad GOOD
# wrong sha
python3 - <<PY
import json
m=json.load(open("$TMP/good.json"))
m["sha256"]="0"*64
# resign would be needed - without resign verify should fail on sha after sig... 
# Actually changing sha256 changes canonical payload → sig fails first. Good.
open("$TMP/badsha.json","w").write(json.dumps(m))
PY
# re-sign badsha with wrong content after tampering without resign
soviez_platform_verify_candidate "$TMP/cand.sh" "$TMP/badsha.json" && bad BADSHA || pass BADSHA
# invalid signature
python3 - <<PY
import json
m=json.load(open("$TMP/good.json"))
m["signature_b64url"]="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
m["signature"]=m["signature_b64url"]
open("$TMP/badsig.json","w").write(json.dumps(m))
PY
soviez_platform_verify_candidate "$TMP/cand.sh" "$TMP/badsig.json" && bad BADSIG || pass BADSIG
# unknown signer
python3 - <<PY
import json
m=json.load(open("$TMP/good.json"))
m["signer_key_id"]="unknown-key-id"
open("$TMP/badkey.json","w").write(json.dumps(m))
PY
soviez_platform_verify_candidate "$TMP/cand.sh" "$TMP/badkey.json" && bad BADKEY || pass BADKEY
# downgrade cmp
[[ "$(soviez_platform_version_cmp 0.24.6.3-platform-cli 0.24.6.2-platform-cli)" == "1" ]] && pass DOWNCMP || bad DOWNCMP
[[ "$(soviez_platform_version_cmp 0.24.6.2-platform-cli 0.24.6.2-platform-cli)" == "0" ]] && pass EQCMP || bad EQCMP
older="$(soviez_platform_version_cmp 0.24.6.1-platform-cli 0.24.6.2-platform-cli 2>/tmp/vcmp.err)"
[[ "$older" == "-1" ]] && pass OLDCMP || bad OLDCMP
if grep -q 'invalid option' /tmp/vcmp.err 2>/dev/null; then bad PRINTFWARN; else pass PRINTFWARN; fi

echo "ed25519_matrix ok=$ok fail=$fail"
[[ $fail -eq 0 ]]
