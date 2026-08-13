#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="$(mktemp -d)"
soviez_paths_init

secret="SOV-TEST-KEY-ABCDEF"
soviez_tenant_secret_write activation_key "$secret"
stored="$(soviez_tenant_secret_read activation_key)"
assert_eq "$secret" "$stored"

perm="$(stat -f '%Lp' "$(soviez_tenant_secret_path activation_key)" 2>/dev/null || stat -c '%a' "$(soviez_tenant_secret_path activation_key)")"
assert_eq "600" "$perm"

log_out="$(soviez_redact_text "leak $secret")"
assert_not_contains "$log_out" "$secret"

echo "test_secret_handling: PASS"
