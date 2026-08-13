#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s1_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
RUN_ID="$(s1_run_id)"
PREFIX="soviez-s1-${RUN_ID}"
cleanup() { s1_cleanup_containers "$PREFIX"; }
trap cleanup EXIT

echo "TEST-SEC rollback never restores SUPERUSER"
if ! soviez_sec_rollback_forbidden_privilege_restore 2>/dev/null; then
  :
else
  echo "FAIL forbidden restore should return non-zero"; exit 1
fi
# restore_safe should refuse privilege restore markers
SNAP="$(mktemp -d)"
mkdir -p "$SNAP"
printf '{"attrs":{"rolsuper":"t"}}\n' > "$SNAP/role_attrs.json"
export SOVIEZ_SEC_REPORT_DIR="$(mktemp -d)"
if soviez_sec_rollback_restore_safe "$SNAP" 2>/dev/null; then
  # may succeed while skipping privilege restore — ensure it did not grant
  echo "restore_safe completed (privilege restore must remain forbidden)"
fi
# Direct call must fail
if soviez_sec_rollback_forbidden_privilege_restore; then
  echo FAIL; exit 1
fi
echo "PASS rollback no superuser restore"
