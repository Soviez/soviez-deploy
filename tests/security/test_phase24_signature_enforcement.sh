#!/usr/bin/env bash
# Phase 24 — signature enforcement (production fail-closed).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p24-sig.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1 SOVIEZ_DISPOSABLE_ENV=1
soviez_paths_init 2>/dev/null || true
soviez_update_paths_init 2>/dev/null || true

ARCH="$(uname -m)"
DIGEST="sha256:$(printf p24a | shasum -a 256 | awk '{print $1}')"

# Valid-looking fixture under disposable bypass
export SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON
SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON="$(python3 - <<PY
import json
print(json.dumps({"release_id":"r1","digest":"$DIGEST","signed":True,"signature":"sig-valid-fixture","architecture":"$ARCH","erp_major":"18","image_ref":"soviez/erp@$DIGEST"},separators=(",",":")))
PY
)"
soviez_update_release_assert "$(soviez_update_release_resolve stable)" "$ARCH" >/dev/null

# Unsigned denied even with TEST_MODE when production forced
export SOVIEZ_SECURITY_FORCE_PRODUCTION=1 SOVIEZ_PHASE24_FORBID_TEST_BYPASS=1
set +e
out="$(soviez_security_require_signed_manifest false "" release 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]
printf '%s' "$out" | grep -Eq 'UNSIGNED|SIGNATURE_REQUIRED|SECURITY_' || {
  # update_die path
  printf '%s' "$out" | grep -Eq 'Unsigned|UPDATE_RELEASE_UNSIGNED' 
}

# Fake signature denied on production
set +e
out="$(soviez_security_require_signed_manifest true ok release 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]

# STRICT_SIG=0 alone must not bypass production
export SOVIEZ_UPDATE_STRICT_SIG=0
set +e
out="$(soviez_security_require_signed_manifest true fixture release 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]

# Checksum/digest without signature is not authorization
set +e
out="$(soviez_security_require_signed_manifest true "" release 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]]

echo "OK test_phase24_signature_enforcement"
exit 0
