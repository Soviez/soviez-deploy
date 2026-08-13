#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
soviez_paths_init
soviez_stage_paths_init

# CLI parsing
(
  set +e
  soviez_cli_parse --help >/dev/null
)
soviez_cli_parse --stage-list
assert_eq "stage-list" "$SOVIEZ_CLI_COMMAND"

soviez_cli_parse --stage --stage-id abc12 --stage-domain stage.example.com --production-tenant t1
assert_eq "stage" "$SOVIEZ_CLI_COMMAND"
assert_eq "abc12" "$SOVIEZ_CLI_STAGE_ID"
assert_eq "stage.example.com" "$SOVIEZ_CLI_STAGE_DOMAIN"

soviez_cli_parse --stage-status my_stage
assert_eq "stage-status" "$SOVIEZ_CLI_COMMAND"
assert_eq "my_stage" "$SOVIEZ_CLI_STAGE_TARGET"

# State machine
soviez_stage_sm_assert created preflight
soviez_stage_sm_assert ticket_verified snapshot_preparing
soviez_stage_sm_allowed_next created completed && exit 1 || true

# Inventory uniqueness
id1="$(soviez_stage_identity_reserve stagea tenant1 aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa \
  prod_fp db-uuid stagea.example.com \
  sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  op-1)"
assert_contains "$id1" stagea

set +e
( soviez_stage_identity_reserve stageb tenant1 aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa \
  prod_fp db-uuid stagea.example.com \
  sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  op-2 >/dev/null 2>&1 )
rc=$?
set -e
assert_eq 20 "$rc" "duplicate domain should denial-exit"

# Admission
adm="$(soviez_stage_admission_evaluate 1000 1000)"
assert_contains "$adm" commercial_limit
assert_contains "$adm" unlimited

# Domain normalize
d="$(soviez_stage_normalize_domain 'HTTPS://Stage.Example.COM/path')"
assert_eq "stage.example.com" "$d"

# Self-signed rejection path
tmpc="$(mktemp)"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tmpc.key" -out "$tmpc" -days 1 -subj "/CN=self" >/dev/null 2>&1
set +e
( soviez_ssl_validate_chain "$tmpc" >/dev/null 2>&1 )
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo "self-signed should fail without CA"; exit 1; }

echo "test_stage_unit: PASS"
