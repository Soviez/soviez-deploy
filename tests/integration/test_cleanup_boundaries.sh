#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/integration_env.sh
source "$ROOT/tests/helpers/integration_env.sh"

start_mock
trap stop_mock EXIT
setup_test_env

op_id="$(env SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="$SOVIEZ_ROOT" SOVIEZ_SAAS_BASE_URL="$SOVIEZ_SAAS_BASE_URL" \
  SOVIEZ_REGISTRY_GATEWAY_URL="$SOVIEZ_REGISTRY_GATEWAY_URL" SOVIEZ_AUTO_CONSENT=1 \
  SOVIEZ_ODOO_STUB="$SOVIEZ_ODOO_STUB" "$ROOT/dist/soviez.sh" --new --activation automatic)"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT
soviez_paths_init

# Pull client must not leave docker config dirs behind
leftover="$(find "$TMPDIR" /tmp -maxdepth 1 -name 'soviez-docker-config.*' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$leftover"

# No global docker prune invoked — sentinel only
assert_file_exists "$SOVIEZ_ROOT/stubs/container-${op_id}.started"

echo "test_cleanup_boundaries: PASS"
