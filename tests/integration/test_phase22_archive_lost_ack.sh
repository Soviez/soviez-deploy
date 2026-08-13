#!/usr/bin/env bash
# Phase 22 G3 — lost acknowledgment after remote write + idempotent replay.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=0
export SOVIEZ_PHASE22_REQUIRE_REAL_S3=0
export SOVIEZ_PHASE22_REQUIRE_REAL_SFTP=0
# Lost-ack path works for local_only when we inject after write_completed with a fake receipt,
# or via SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK during local receipt path.
# Use local-only store with LOST_ACK after write_completed by enabling a noop remote via interrupt path:
# For local_only, store writes receipt immediately as local_only — so inject via ARCHIVE_UPLOAD_INTERRUPT
# then LOST_ACK on a crafted receipt.

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
soviez_migration_rollback_window_close "$CUTOVER_OP_ID" >/dev/null
archive="$(soviez_migration_source_archive_start "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$archive" operation_id)"

op_dir="$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")"
receipt="$(soviez_migration_p22_archive_store_receipt_path "$ARCHIVE_OP")"
ackf="$(soviez_migration_p22_archive_store_ack_path "$ARCHIVE_OP")"

# Simulate write_completed without ack (lost-ack window)
python3 - <<PY
import json
body={
  "schema":"soviez.migration_source_archive_remote_store.v1",
  "operation_id":"$ARCHIVE_OP",
  "kind":"local_only",
  "profile_id":"",
  "object":"archive_bundle.tar.enc",
  "write_completed": True,
  "status":"write_completed",
  "purge_authorized": False,
  "deletion_performed": False,
  "duplicate_upload": False,
}
open("$receipt","w").write(json.dumps(body, separators=(",", ":")))
PY
rm -f "$ackf"

export SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK=1
set +e
out="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: expected lost-ack interrupt"; exit 1; }
echo "$out" | grep -q MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED
[[ -f "$receipt" ]]
[[ ! -f "$ackf" ]]

# Replay without inject → ack without re-upload / no duplicate
unset SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK
export SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK=0
out2="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$out2" status)" "stored" "acked after lost-ack"
assert_eq "$(soviez_json_get "$out2" duplicate_upload)" "False" "no duplicate upload" || \
  [[ "$(soviez_json_get "$out2" duplicate_upload)" == "false" ]]
[[ -f "$ackf" ]]
[[ -f "$op_dir/archive_bundle.tar.enc" ]]

# Second replay still idempotent stored
out3="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$out3" status)" "stored" "idempotent"

echo "test_phase22_archive_lost_ack: PASS"
