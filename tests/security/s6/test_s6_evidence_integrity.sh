#!/usr/bin/env bash
# S6 — evidence integrity: blob + sha256 + tamper detect.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-evid.XXXXXX")}"
ev="$(s6_evidence_init "$(s6_run_id)")"
trap '[[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"' EXIT

blob="$ev/artifacts/evidence_blob.json"
mkdir -p "$ev/artifacts" "$ev/hashes"
cat >"$blob" <<'EOF'
{"gate":"S6","kind":"certification_blob","mutation_count":0,"payload":"synthetic"}
EOF
hash="$(s6_hash_file "$blob")"
printf '%s  %s\n' "$hash" "$blob" >"$ev/hashes/manifest.sha256"
echo "OK hashed blob $hash"

# Verify match
actual="$(s6_hash_file "$blob")"
[[ "$actual" == "$hash" ]] || { echo "FAIL hash mismatch before tamper" >&2; exit 1; }

# Tamper → detect mismatch
echo '"tamper":true' >>"$blob"
after="$(s6_hash_file "$blob")"
[[ "$after" != "$hash" ]] || { echo "FAIL tamper did not change hash" >&2; exit 1; }

# Manifest verify should fail
set +e
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  exp="$(printf '%s' "$line" | awk '{print $1}')"
  path="$(printf '%s' "$line" | awk '{print $2}')"
  got="$(s6_hash_file "$path")"
  if [[ "$got" != "$exp" ]]; then
    echo "OK detected mismatch expected=$exp got=$got"
    mismatched=1
    break
  fi
done <"$ev/hashes/manifest.sha256"
set -e
[[ "${mismatched:-0}" -eq 1 ]] || { echo "FAIL tamper not detected via manifest" >&2; exit 1; }

# Also exercise S3 evidence verify path when available
export SOVIEZ_SEC_S3_EVIDENCE_ROOT="$ev/artifacts/s3wrap"
mkdir -p "$SOVIEZ_SEC_S3_EVIDENCE_ROOT"
if declare -F soviez_s3_evidence_init >/dev/null 2>&1; then
  sev="$(soviez_s3_evidence_init "s6-evid-integ")"
  echo '{"status":"PASS"}' >"$sev/findings/findings.json"
  soviez_s3_evidence_finalize "$sev" PASS >/dev/null
  soviez_s3_evidence_verify "$sev"
  echo tamper >>"$sev/findings/findings.json"
  set +e
  soviez_s3_evidence_verify "$sev"
  rc=$?
  set -e
  [[ $rc -ne 0 ]] || { echo "FAIL s3 evidence verify should fail after tamper" >&2; exit 1; }
  echo "OK s3 evidence verify detects tamper"
fi

s6_write_json "$ev/findings/evidence_integrity.json" '{"status":"PASS","tamper_detected":true}'
echo PASS
