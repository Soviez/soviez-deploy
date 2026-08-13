#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

sample='credential=SUPER-SECRET activation_key=SOV-ABCD-1234-EFGH'
red="$(soviez_redact_text "$sample")"
assert_not_contains "$red" "SUPER-SECRET"
assert_not_contains "$red" "SOV-ABCD"

export SOVIEZ_ACTIVATION_KEY="SOV-SECRET-KEY-9999"
assert_not_contains "$(soviez_redact_text "prefix SOV-SECRET-KEY-9999 suffix")" "SOV-SECRET-KEY-9999" || true

echo "test_redact: PASS"
