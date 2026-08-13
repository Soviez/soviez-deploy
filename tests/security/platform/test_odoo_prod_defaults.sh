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

echo "TEST-SEC odoo prod defaults"
TMP="$(mktemp)"
cat > "$TMP" <<EOF
[options]
list_db = True
proxy_mode = False
EOF
soviez_sec_odoo_conf_ensure_production_defaults "$TMP" "^production$"
soviez_sec_odoo_conf_assert_production_defaults "$TMP"
grep -Eiq 'proxy_mode[[:space:]]*=[[:space:]]*True' "$TMP"
grep -Eiq 'list_db[[:space:]]*=[[:space:]]*False' "$TMP"
rm -f "$TMP"
echo "PASS odoo prod defaults"
