#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="$(mktemp -d)"
soviez_paths_init

self_signed="$SOVIEZ_ROOT/self.crt"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$SOVIEZ_ROOT/self.key" -out "$self_signed" -days 1 -subj "/CN=test.local" >/dev/null 2>&1
if ( soviez_ssl_validate_chain "$self_signed" ) >/dev/null 2>&1; then
  echo "self-signed should fail" >&2
  exit 1
fi

ssl_lines="$(soviez_ssl_local_issue_cert test.local.soviez)"
cert="$(printf '%s\n' "$ssl_lines" | sed -n '1p')"
ca="$(printf '%s\n' "$ssl_lines" | sed -n '3p')"
soviez_ssl_validate_chain "$cert" "$ca"

echo "test_domain_ssl: PASS"
