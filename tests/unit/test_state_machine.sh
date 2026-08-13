#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_sm_is_valid_state completed
assert_ok "completed valid"
soviez_sm_is_valid_state not_a_state && exit 1 || true

soviez_sm_assert_transition created preflight
soviez_sm_assert_transition preflight waiting_for_connection_consent
soviez_sm_assert_transition validating completed

if soviez_sm_allowed_next created completed; then
  echo "illegal transition allowed" >&2
  exit 1
fi

assert_eq 0 "$(soviez_sm_resume_index created)"
assert_eq 23 "$(soviez_sm_resume_index completed)"

soviez_sm_should_run_step device_authorized image_pulled || exit 1
soviez_sm_should_run_step completed preflight && exit 1 || true

echo "test_state_machine: PASS"
