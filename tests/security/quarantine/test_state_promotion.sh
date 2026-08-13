#!/usr/bin/env bash
# Quarantine state, promotion gates, secrets, review, rollback, locks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s4_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d)"
trap 'rm -rf "$SOVIEZ_SEC_QUARANTINE_ROOT"' EXIT

export SOVIEZ_Q_TRUST=EXTERNAL_UNKNOWN
qid="$(soviez_q_create)"
[[ "$(soviez_q_get_state "$qid")" == "UNTRUSTED_RESTORED" ]]
# Idempotent create
qid2="$(soviez_q_create "$qid")"
[[ "$qid" == "$qid2" ]]

soviez_q_generate_fresh_secrets "$qid" >/dev/null
src="$(mktemp)"
echo "SOVIEZ_Q_PG_ADMIN_PASSWORD=samepass" >"$src"
# Force conflict by copying dest secret into source file content match test —
# generate fresh then ensure source file with different values passes
echo "OLD_PASSWORD=sourceonly" >"$src"
soviez_q_assert_secrets_fresh_vs_source "$qid" "$src" | grep -q FRESH

# Cannot promote without scan/egress
set +e
soviez_q_promote "$qid" APPROVED_FOR_STAGE 2>/dev/null
prc=$?
set -e
[[ $prc -ne 0 ]]

# Fake scan PASS_WITH_REVIEW requires review
mkdir -p "$(soviez_q_dir "$qid")/scans" "$(soviez_q_dir "$qid")/network"
echo PASS_WITH_REVIEW >"$(soviez_q_dir "$qid")/scans/preboot.status"
echo BLOCKED >"$(soviez_q_dir "$qid")/network/egress_proof.txt"
soviez_q_set_state "$qid" "REVIEW_REQUIRED" >/dev/null
set +e
soviez_q_promote "$qid" APPROVED_FOR_STAGE 2>/dev/null
prc=$?
set -e
[[ $prc -ne 0 ]]

soviez_q_accept_review "$qid" "tester" "ok"
soviez_q_promote "$qid" APPROVED_FOR_STAGE "tester"
[[ "$(soviez_q_get_state "$qid")" == "PROMOTED" ]]

# No auto on PASS alone — new qid
export SOVIEZ_Q_TRUST=EXTERNAL_UNKNOWN
qidb="$(soviez_q_create)"
soviez_q_generate_fresh_secrets "$qidb" >/dev/null
mkdir -p "$(soviez_q_dir "$qidb")/scans" "$(soviez_q_dir "$qidb")/network"
echo PASS >"$(soviez_q_dir "$qidb")/scans/preboot.status"
echo BLOCKED >"$(soviez_q_dir "$qidb")/network/egress_proof.txt"
soviez_q_set_state "$qidb" "QUARANTINED" >/dev/null
# Still not promoted until explicit promote
[[ "$(soviez_q_get_state "$qidb")" != "PROMOTED" ]]
soviez_q_promote "$qidb" APPROVED_FOR_PRODUCTION "tester"
[[ "$(soviez_q_get_state "$qidb")" == "PROMOTED" ]]

# Rollback
soviez_q_rollback_to_quarantine "$qidb" "validation_failed"
[[ "$(soviez_q_get_state "$qidb")" == "QUARANTINED" ]]

# CRITICAL scan blocks
qidc="$(soviez_q_create)"
soviez_q_generate_fresh_secrets "$qidc" >/dev/null
mkdir -p "$(soviez_q_dir "$qidc")/scans" "$(soviez_q_dir "$qidc")/network"
echo FAIL >"$(soviez_q_dir "$qidc")/scans/preboot.status"
echo BLOCKED >"$(soviez_q_dir "$qidc")/network/egress_proof.txt"
soviez_q_set_state "$qidc" "SCAN_FAILED" >/dev/null
set +e
soviez_q_promote "$qidc" 2>/dev/null
prc=$?
set -e
[[ $prc -ne 0 ]]

# Concurrency lock
soviez_q_acquire_lock "$qid" "scan"
set +e
soviez_q_acquire_lock "$qid" "promote" 2>/dev/null
lrc=$?
set -e
[[ $lrc -ne 0 ]]
soviez_q_release_lock "$qid"

# Incident preserve — unique id path
export SOVIEZ_Q_TRUST=COMPROMISED_CONFIRMED
qidi="$(soviez_q_create)"
[[ -f "$(soviez_q_dir "$qidi")/PRESERVE" ]]
[[ -f "$(soviez_q_dir "$qidi")/INCIDENT" ]]
out="$(soviez_q_cleanup_temps "$qidi")"
[[ "$out" == *PRESERVE* ]]
[[ -f "$(soviez_q_dir "$qidi")/meta.json" ]]

# Classify
SOVIEZ_Q_LOCAL_SOVIEZ=1 SOVIEZ_Q_BACKUP_SIGNED=1 soviez_q_classify_source | grep -q TRUSTED_SIGNED
SOVIEZ_Q_LEGACY_ODOO=1 SOVIEZ_Q_LOCAL_SOVIEZ=0 SOVIEZ_Q_BACKUP_SIGNED=0 soviez_q_classify_source | grep -q LEGACY

echo PASS
