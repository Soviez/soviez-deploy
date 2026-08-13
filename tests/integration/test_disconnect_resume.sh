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

# Simulate partial run by creating an operation mid-flight, then resume.
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT SOVIEZ_SAAS_BASE_URL SOVIEZ_AUTO_CONSENT=1
soviez_paths_init

op_id="resume-test-op"
soviez_op_create "$op_id"
soviez_op_transition "$op_id" preflight
soviez_op_transition "$op_id" waiting_for_connection_consent
soviez_op_transition "$op_id" device_authorization_pending

op_id="$(env SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="$SOVIEZ_ROOT" SOVIEZ_SAAS_BASE_URL="$SOVIEZ_SAAS_BASE_URL" \
  SOVIEZ_REGISTRY_GATEWAY_URL="$SOVIEZ_REGISTRY_GATEWAY_URL" SOVIEZ_AUTO_CONSENT=1 \
  SOVIEZ_ODOO_STUB="$SOVIEZ_ODOO_STUB" "$ROOT/dist/soviez.sh" --reattach resume-test-op --activation automatic --domain resume.local)"
assert_eq "completed" "$(soviez_op_read_state "$op_id")"

echo "test_disconnect_resume: PASS"
