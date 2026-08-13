#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
soviez_paths_init
soviez_device_ensure_keys

canonical="$(soviez_signing_build_canonical POST /api/installer/slots/reserve 1700000000 testnonce '{"a":1}' dev-1 cred-1)"
assert_contains "$canonical" $'device-auth/v1\nPOST\n/api/installer/slots/reserve'

domain="$(soviez_signing_with_domain "$canonical")"
assert_contains "$domain" "soviez.device-auth.v1"

sig="$(soviez_signing_sign_request POST /api/installer/slots/reserve 1700000000 testnonce '{"a":1}' dev-1 cred-1)"
[[ -n "$sig" ]]

proof="$(soviez_signing_build_token_proof deadbeef deadnonce)"
assert_contains "$proof" "token-proof"

echo "test_signing: PASS"
