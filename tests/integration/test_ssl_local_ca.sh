#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/integration_env.sh
source "$ROOT/tests/helpers/integration_env.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="$(mktemp -d)"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"
soviez_paths_init

ssl_lines="$(soviez_ssl_local_issue_cert ssl-test.local)"
cert="$(printf '%s\n' "$ssl_lines" | sed -n '1p')"
ca="$(printf '%s\n' "$ssl_lines" | sed -n '3p')"
soviez_ssl_validate_chain "$cert" "$ca"
soviez_nginx_render_config ssl-test.local "web:8069"

assert_file_exists "$SOVIEZ_ROOT/stubs/nginx-ssl-test.local.conf"

echo "test_ssl_local_ca: PASS"
