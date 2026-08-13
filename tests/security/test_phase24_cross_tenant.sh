#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

# Cross-tenant / cross-purpose denial
set +e
(soviez_security_ticket_deny_confusion registry_pull update_apply) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

set +e
(soviez_security_die SECURITY_CROSS_TENANT_DENIED "tenant-b cannot use tenant-a ticket") >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

# Two ticket purposes cannot authorize each other
set +e
(soviez_security_ticket_purpose_assert registry_pull update_apply) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
soviez_security_ticket_purpose_assert registry_pull registry_pull

echo "OK test_phase24_cross_tenant"
exit 0
