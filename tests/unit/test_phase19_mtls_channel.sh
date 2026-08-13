#!/usr/bin/env bash
# Phase 19 — real mTLS chunk channel (not local_filesystem)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1 SOVIEZ_MIG_TLS_FIXTURE=1
# Explicitly NOT local — force real mTLS receiver/client
export SOVIEZ_MIG_TRANSFER_LOCAL=0
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p19-mtls.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

PAIR_ID="pair-mtls-p19"
OP_ID="op-mtls-p19"
MID="man-mtls-p19"
soviez_migration_mtls_issue_pair "$PAIR_ID" "xfer-src-$PAIR_ID" "xfer-dst-$PAIR_ID" >/dev/null

CH="$(soviez_migration_channel_init "$PAIR_ID" "$OP_ID" "$MID")"
echo "$CH" | grep -q '"mode":"mtls"'
PORT="$(soviez_json_get "$CH" listen_port)"
[[ -n "$PORT" ]]

PAYLOAD="$(mktemp)"
printf 'payload-bytes-for-mtls-chunk-%s' "$(openssl rand -hex 16)" > "$PAYLOAD"
DIGEST="$(openssl dgst -sha256 "$PAYLOAD" | awk '{print $NF}')"

PUT="$(soviez_migration_channel_put "$OP_ID" "chunk-000001" "$PAYLOAD")"
echo "$PUT" | grep -q '"mode":"mtls"'
[[ -f "$(soviez_migration_transfer_channel_dir "$OP_ID")/inbox/chunk-000001.chunk" ]]
GOT_DIGEST="$(cat "$(soviez_migration_transfer_channel_dir "$OP_ID")/inbox/chunk-000001.chunk.sha256")"
assert_eq "$DIGEST" "$GOT_DIGEST" "mTLS received digest"

# Idempotent replay
PUT2="$(soviez_migration_channel_put "$OP_ID" "chunk-000001" "$PAYLOAD")"
echo "$PUT2" | grep -Eq 'idempotent|received'

# Wrong CA denial via Phase 17 helper
soviez_migration_mtls_deny_substituted_ca "$PAIR_ID"

soviez_migration_channel_shutdown "$OP_ID"
rm -f "$PAYLOAD"
echo "test_phase19_mtls_channel: PASS"
