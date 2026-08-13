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
  SOVIEZ_ODOO_STUB="$SOVIEZ_ODOO_STUB" "$ROOT/dist/soviez.sh" --new --domain test-auto.local --activation automatic)"
assert_ne "" "$op_id"

# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT SOVIEZ_SAAS_BASE_URL
soviez_paths_init

state="$(soviez_op_read_state "$op_id")"
assert_eq "completed" "$state"

assert_file_exists "$SOVIEZ_ROOT/stubs/odoo-activate-soviez_${op_id//-/_}.invoked"

events="$(cat "$SOVIEZ_ROOT/ops/operations/$op_id/events.jsonl")"
assert_not_contains "$events" "SOV-MOCK-KEY-0001"

echo "test_new_automatic_path: PASS"
