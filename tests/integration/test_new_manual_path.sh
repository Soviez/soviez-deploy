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
  "$ROOT/dist/soviez.sh" --new --activation manual)"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT SOVIEZ_SAAS_BASE_URL
soviez_paths_init

state="$(soviez_op_read_state "$op_id")"
assert_eq "completed_activation_pending" "$state"

echo "test_new_manual_path: PASS"
