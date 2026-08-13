#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_SEC_S3_EVIDENCE_ROOT
SOVIEZ_SEC_S3_EVIDENCE_ROOT="$(mktemp -d)"
trap 'rm -rf "$SOVIEZ_SEC_S3_EVIDENCE_ROOT"' EXIT

ev="$(soviez_s3_evidence_init "s3-ev-test")"
echo '{"status":"PASS","findings":[],"mutation_count":0}' >"$ev/findings/findings.json"
soviez_s3_evidence_finalize "$ev" PASS >/dev/null
soviez_s3_evidence_verify "$ev"

# Tamper
echo tamper >>"$ev/findings/findings.json"
set +e
soviez_s3_evidence_verify "$ev"
rc=$?
set -e
[[ $rc -ne 0 ]]

# Fail-closed missing rules
bad="$(mktemp -d)"
export SOVIEZ_S3_SHARE_DIR="$bad"
set +e
soviez_security_validate_compromise_detection
rc=$?
set -e
[[ $rc -ne 0 ]]
export SOVIEZ_S3_SHARE_DIR="$ROOT/share/security/detection"

# Retention respects PRESERVE
runp="$SOVIEZ_SEC_S3_EVIDENCE_ROOT/old-preserve"
mkdir -p "$runp"
touch "$runp/PRESERVE"
echo PASS >"$runp/STATUS"
export SOVIEZ_S3_RETENTION_MAX_AGE_DAYS=0
export SOVIEZ_S3_RETENTION_MAX_RUNS=0
soviez_s3_retention_cleanup || true
[[ -d "$runp" ]]

# Tooling policy
soviez_s3_optional_tools_status | grep -q wazuh
[[ "$(soviez_s3_lynis_decision)" == "SUPPORTING_ONLY_ON_DEMAND" ]]

echo PASS
