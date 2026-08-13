#!/usr/bin/env bash
# Phase 16 — secret handling audit for destination/encryption paths.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_PASSPHRASE="super-secret-passphrase-do-not-leak"
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p16-sec.XXXXXX")"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init

PROD=prod-sec
mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore"
printf 'x\n' > "$SOVIEZ_TENANT_DIR/$PROD/filestore/a"
printf 'd\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/m"
HOST="$(hostname -f 2>/dev/null || hostname)"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic","database_uuid":"55555555-5555-5555-5555-555555555555",
  "database_name":"db","host_identity":"$HOST","fingerprint":"fp","production_fingerprint":"fp",
  "erp_major":"18","filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "current_digest":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
},separators=(",",":")))
PY

soviez_backup_destination_write '{"profile_id":"s3sec","kind":"s3","endpoint":"http://127.0.0.1:9","bucket":"b","prefix":"p"}' >/dev/null
soviez_backup_destination_write_secret s3sec '{"access_key":"AKIA_TEST_KEY","secret_key":"SECRET_S3_VALUE_XYZ"}'

out="$(soviez_backup_run "$PROD" local-primary full 1)"
echo "$out" | grep -q BACKUP_COMPLETED

# Secrets must not appear in stdout, inventory, op state, or profile JSON
for needle in super-secret-passphrase-do-not-leak SECRET_S3_VALUE_XYZ AKIA_TEST_KEY; do
  echo "$out" | grep -F "$needle" && { echo "leak in stdout: $needle" >&2; exit 1; } || true
  if grep -R --fixed-strings "$needle" "$SOVIEZ_BACKUP_INVENTORY_DIR" "$SOVIEZ_BACKUP_OPS_DIR" "$SOVIEZ_BACKUP_DEST_DIR" 2>/dev/null; then
    echo "leak in state/dest/inventory: $needle" >&2; exit 1
  fi
done

# Profile scrubbed
! grep -E 'secret_key|access_key|passphrase' "$SOVIEZ_BACKUP_DEST_DIR/s3sec.json"

# Secret file mode
sf="$(soviez_backup_dest_secret_file s3sec)"
mode="$(stat -f '%Lp' "$sf" 2>/dev/null || stat -c '%a' "$sf")"
[[ "$mode" == "600" ]] || { echo "secret mode $mode not 600" >&2; exit 1; }

echo "PASS test_phase16_secret_handling"
rm -rf "$SOVIEZ_ROOT"
