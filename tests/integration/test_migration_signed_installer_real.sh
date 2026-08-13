#!/usr/bin/env bash
# Phase 17 final — real signed installer (HMAC + device Ed25519) paths
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p17-inst.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

DIGEST="sha256:$(printf inst-real | openssl dgst -sha256 | awk '{print $NF}')"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"

# HMAC-signed exact package
GOOD="$(python3 - <<PY
import json,hmac,hashlib
body={"version":"0.17.0-phase17","digest":"$DIGEST","architecture":"amd64","tag":"0.17.0-phase17","signer":"soviez-release","expires_at":"2099-01-01T00:00:00Z"}
canon=json.dumps(body, sort_keys=True, separators=(",",":"))
body["checksum"]=hashlib.sha256(canon.encode()).hexdigest()
body["signature"]=hmac.new(b"soviez-test-release-key", canon.encode(), hashlib.sha256).hexdigest()
print(json.dumps(body))
PY
)"
OUT="$(soviez_migration_installer_verify "$GOOD")"
[[ "$(soviez_json_get "$OUT" version)" == "0.17.0-phase17" ]]

# Device-signed package
CANON="$(python3 - <<PY
import json
body={"version":"0.17.0-phase17","digest":"$DIGEST","architecture":"amd64","tag":"0.17.0-phase17","signer":"soviez-device","expires_at":"2099-01-01T00:00:00Z"}
print(json.dumps(body, sort_keys=True, separators=(",",":")))
PY
)"
SIG="$(soviez_migration_sign_json "$CANON")"
DEV="$(CANON="$CANON" SIG="$SIG" python3 - <<'PY'
import json, os
body=json.loads(os.environ["CANON"])
body["signature"]=os.environ["SIG"]
body["checksum"]="x"
print(json.dumps(body))
PY
)"
soviez_migration_installer_verify "$DEV" >/dev/null

# Negatives
( soviez_migration_installer_verify '{"version":"x","digest":"sha256:dead","architecture":"amd64","tag":"latest","signer":"x","expires_at":"2099-01-01T00:00:00Z","signature":"x"}' ) 2>/dev/null && exit 1 || true
( soviez_migration_installer_verify '{"version":"0.17.0-phase17","digest":"sha256:wrong","architecture":"amd64","tag":"0.17.0-phase17","signer":"soviez-release","expires_at":"2099-01-01T00:00:00Z","signature":"dead"}' ) 2>/dev/null && exit 1 || true
( SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST" soviez_migration_installer_verify "$(python3 - <<PY
import json,hmac,hashlib
body={"version":"0.17.0-phase17","digest":"sha256:0000000000000000000000000000000000000000000000000000000000000000","architecture":"amd64","tag":"0.17.0-phase17","signer":"soviez-release","expires_at":"2099-01-01T00:00:00Z"}
canon=json.dumps(body, sort_keys=True, separators=(",",":"))
body["signature"]=hmac.new(b"soviez-test-release-key", canon.encode(), hashlib.sha256).hexdigest()
print(json.dumps(body))
PY
)" ) 2>/dev/null && exit 1 || true

# Offline package path
PKG="$SOVIEZ_ROOT/installer-pkg.json"
printf '%s' "$GOOD" > "$PKG"
export SOVIEZ_MIG_INSTALLER_PACKAGE_PATH="$PKG"
soviez_migration_installer_verify >/dev/null

# Unsigned self-update absence in migration tree
rg -n 'curl .*\|.*bash|unsigned self-update' src/migration >/dev/null 2>&1 && exit 1 || true

echo "test_migration_signed_installer_real: PASS"
