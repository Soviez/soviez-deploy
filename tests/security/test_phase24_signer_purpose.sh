#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

set +e
out="$(soviez_security_signer_purpose_assert release authorization 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]

soviez_security_signer_purpose_assert release release

set +e
(soviez_security_ticket_deny_confusion registry_pull update_apply) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

set +e
(soviez_security_ticket_deny_confusion offline_update activation) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

set +e
(soviez_security_ticket_deny_confusion migration_auth registry_pull) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

echo "OK test_phase24_signer_purpose"
exit 0
