#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

body='{"slot":"1"}'
h1="$(soviez_signing_body_hash "$body")"
h2="$(soviez_sha256_hex "$body")"
assert_eq "$h1" "$h2"

echo "test_digest: PASS"
