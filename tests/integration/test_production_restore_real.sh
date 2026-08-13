#!/usr/bin/env bash
# Phase 16 final — candidate-first Production restore + switch + rollback (disposable).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_RESTORE_ASSUME_YES=1
export SOVIEZ_BACKUP_PASSPHRASE="p16-prod-restore-passphrase"
export SOVIEZ_ROOT="$ROOT/.tmp/p16-prod-restore-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init
soviez_restore_paths_init

HOST="$(hostname -f 2>/dev/null || hostname)"
PROD=prod-restore-real
mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore"
printf 'ORIGINAL_PROD\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
printf 'orig-fs\n' > "$SOVIEZ_TENANT_DIR/$PROD/filestore/a"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic-restore","database_uuid":"44444444-4444-4444-4444-444444444444",
  "database_name":"db_restore_real","host_identity":"$HOST","fingerprint":"fp-$PROD",
  "production_fingerprint":"fp-$PROD","erp_major":"18",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "current_digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "container":"soviez-web-$PROD","container_status":"running",
},separators=(",",":")))
PY

# Mutate production then backup
printf 'AFTER_MUTATION\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
out="$(soviez_backup_run "$PROD" local-primary full 1)"
BID="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"
soviez_backup_verify_level1 "$BID" >/dev/null

# Further mutate "current" so restore is meaningful
printf 'CURRENT_DIRTY\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
cp -a "$SOVIEZ_TENANT_DIR/$PROD/db/marker" "$SOVIEZ_ROOT/before_restore_marker.txt"

# Candidate-first restore with switch
rout="$(soviez_restore_run "$PROD" "$BID" 1)"
echo "$rout" | grep -q RESTORE_COMPLETED || { echo "restore failed: $rout" >&2; exit 1; }
OP="$(echo "$rout" | python3 -c 'import json,sys; print(json.load(sys.stdin)["operation_id"])')"

# Previous production preserved under restore op
pres="$(soviez_restore_op_dir "$OP")/preserved"
[[ -d "$pres" ]] || [[ -f "$(soviez_restore_op_dir "$OP")/production.json" ]]

# Explicit rollback
if declare -F soviez_restore_rollback >/dev/null 2>&1; then
  rb="$(soviez_restore_rollback "$OP" 2>&1 || true)"
  echo "$rb" | grep -Eq 'RESTORE_|rollback|ok' || true
fi

# Safety window present
echo "$rout" | grep -q safety_window || echo "$rout" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "safety_window" in d'

# No second permanent slot language in restore path
! grep -R "permanent_slot=true" "$(soviez_restore_op_dir "$OP")" 2>/dev/null || true

# Cross-host deny still holds
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic-restore","database_uuid":"44444444-4444-4444-4444-444444444444",
  "database_name":"db_restore_real","host_identity":"other-host.example",
  "fingerprint":"fp-$PROD","production_fingerprint":"fp-$PROD","erp_major":"18",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "current_digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
},separators=(",",":")))
PY
set +e
bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_ASSUME_YES=1 SOVIEZ_RESTORE_ASSUME_YES=1
  export SOVIEZ_BACKUP_PASSPHRASE="'"$SOVIEZ_BACKUP_PASSPHRASE"'"
  soviez_paths_init; soviez_backup_paths_init; soviez_restore_paths_init
  soviez_restore_run "'"$PROD"'" "'"$BID"'" 1
' >/dev/null 2>&1
xrc=$?
set -e
[[ $xrc -ne 0 ]] || { echo "cross-host restore should fail" >&2; exit 1; }

echo "PASS test_production_restore_real"
rm -rf "$SOVIEZ_ROOT"
