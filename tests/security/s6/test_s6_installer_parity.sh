#!/usr/bin/env bash
# S6 — installer parity + APT lock safety (ERP ↔ deploy ↔ dist modules).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-parity.XXXXXX")}"
ev="$(s6_evidence_init "$(s6_run_id)")"
trap '[[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"' EXIT

ERP="/Volumes/PortableSSD/soviez-project/Soviez ERP/soviez.sh"
LEG="/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh"
DIST="$ROOT/dist/soviez.sh"
VER_FILE="$ROOT/VERSION"

[[ -f "$DIST" ]] || { echo "FAIL missing dist/soviez.sh" >&2; exit 1; }
[[ -f "$VER_FILE" ]] || { echo "FAIL missing VERSION" >&2; exit 1; }
[[ -f "$ERP" && -f "$LEG" ]] || { echo "FAIL missing ERP/deploy installers" >&2; exit 1; }

actual_ver="$(tr -d '[:space:]' <"$VER_FILE")"
actual_sha="$(s6_hash_file "$DIST")"
expected_ver="${S6_EXPECTED_VERSION}"
expected_sha="${S6_EXPECTED_DIST_SHA256}"

parity_status="PASS"
parity_note="exact_match"
if [[ "$actual_ver" == "$expected_ver" && "$actual_sha" == "$expected_sha" ]]; then
  echo "OK dist version+sha match expected ($expected_ver / ${expected_sha:0:12}…)"
else
  # Record actual for certification evidence; do not auto-bump VERSION here.
  parity_note="recorded_actual"
  if [[ "$actual_ver" != "$expected_ver" ]]; then
    echo "WARN VERSION actual=$actual_ver expected=$expected_ver (recorded)" >&2
  fi
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "WARN dist SHA actual=$actual_sha expected=$expected_sha (recorded)" >&2
    # Cert prefer exact artifact — fail closed unless explicitly allowed.
    if [[ "${SOVIEZ_S6_ALLOW_DIST_SHA_DRIFT:-0}" != "1" ]]; then
      parity_status="FAIL"
    fi
  fi
fi

soviez_sec_legacy_assert_installer_safe "$ERP"
soviez_sec_legacy_assert_installer_safe "$LEG"
soviez_sec_legacy_assert_apt_lock_safe "$ERP"
soviez_sec_legacy_assert_apt_lock_safe "$LEG"
cmp -s "$ERP" "$LEG" || { echo "FAIL ERP != deploy" >&2; exit 1; }
echo "OK ERP == deploy (cmp)"

# No killall -9 apt in supported Production paths (executable lines)
for p in "$ERP" "$LEG" "$DIST"; do
  if grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+apt' "$p" 2>/dev/null; then
    echo "FAIL killall -9 apt in $p" >&2
    exit 1
  fi
done
echo "OK no killall -9 apt in supported paths"

s6_canonical_modules_present "$DIST" || { echo "FAIL canonical modules missing from dist" >&2; exit 1; }
echo "OK canonical modules present (apt_wait / quarantine / detection)"

s6_write_json "$ev/findings/installer_parity.json" "$(cat <<EOF
{
  "status": "$parity_status",
  "note": "$parity_note",
  "expected_version": "$(s6_json_escape "$expected_ver")",
  "actual_version": "$(s6_json_escape "$actual_ver")",
  "expected_sha256": "$(s6_json_escape "$expected_sha")",
  "actual_sha256": "$(s6_json_escape "$actual_sha")",
  "erp_deploy_cmp": "identical",
  "killall_apt_absent": true,
  "canonical_modules": true
}
EOF
)"

[[ "$parity_status" == "PASS" ]] || { echo "FAIL installer parity (see evidence)" >&2; exit 1; }
echo PASS
