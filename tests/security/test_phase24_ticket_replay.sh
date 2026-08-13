#!/usr/bin/env bash
# Ticket replay consolidation — adapters over existing offline/update nonce stores.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p24-replay.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1 SOVIEZ_DISPOSABLE_ENV=1
soviez_paths_init 2>/dev/null || true
soviez_update_paths_init 2>/dev/null || true

ARCH="$(uname -m)"
DIGEST="sha256:$(printf p24r | shasum -a 256 | awk '{print $1}')"
OP="op-p24-replay"
mkdir -p "$(soviez_update_op_dir "$OP" 2>/dev/null || echo "$TMP/op")/offline" 2>/dev/null || true
# Ensure update dirs exist
export SOVIEZ_UPDATE_PACKAGES_DIR="${SOVIEZ_UPDATE_PACKAGES_DIR:-$SOVIEZ_ROOT/update/packages}"
mkdir -p "$SOVIEZ_UPDATE_PACKAGES_DIR"

PKG_DIR="$TMP/pkg1"
mkdir -p "$PKG_DIR"
python3 - <<PY
import json
open("$PKG_DIR/package.json","w").write(json.dumps({
  "package_id":"p24-ticket-1","nonce":"p24-ticket-1","signed":True,"signature":"offline-sig-ok",
  "digest":"$DIGEST","license_id":"lic-a","production_environment_id":"env-a",
  "capability":"product_updates","entitlement_ok":True,
  "architecture":"$ARCH","erp_major":"18"
},separators=(",",":")))
PY

# First use OK
soviez_update_offline_import "$PKG_DIR" "$OP" "lic-a" "env-a" >/dev/null

# Distinct second operation with same ticket => replay denied
OP2="op-p24-replay-2"
set +e
out="$(soviez_update_offline_import "$PKG_DIR" "$OP2" "lic-a" "env-a" 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]
printf '%s' "$out" | grep -qi replay

# Purpose confusion denied
set +e
(soviez_security_ticket_deny_confusion registry_pull update_apply) >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]

echo "OK test_phase24_ticket_replay"
exit 0
