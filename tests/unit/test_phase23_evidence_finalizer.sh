#!/usr/bin/env bash
# Phase 23 evidence finalizer unit tests (G3).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIN="$ROOT/scripts/phase23_evidence_finalizer.py"
chmod +x "$FIN"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-fin.XXXXXX")"
EV="$TMP/evidence"
mkdir -p "$EV"
# Preserve a prior report to prove we don't wipe on validation failure
printf 'PRIOR_REPORT\n' > "$EV/FINAL_REPORT.md"
ART="$TMP/artifact.bin"
printf 'phase23-artifact-bytes\n' > "$ART"
LED="$TMP/ledger.md"
printf '# ledger\nok\n' > "$LED"
SHA="$(shasum -a 256 "$ART" | awk '{print $1}')"

run_expect() {
  local expect_rc="$1"; shift
  set +e
  out="$(python3 "$FIN" "$@" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq "$expect_rc" ]] || { echo "expected rc=$expect_rc got=$rc out=$out"; return 1; }
  printf '%s\n' "$out"
}

echo "== missing variable / artifact =="
run_expect 2 --evidence-dir "$EV" --run-all-exit 0 --auth-exit 0 \
  --artifact "$TMP/missing.bin" --version "0.23.0-phase23" \
  --ok-count 1 --fail-count 0 --ledger "$LED" | grep -q ARTIFACT_MISSING
# prior report preserved
grep -q PRIOR_REPORT "$EV/FINAL_REPORT.md"

echo "== zero tests =="
run_expect 2 --evidence-dir "$EV" --run-all-exit 0 --auth-exit 0 \
  --artifact "$ART" --version "0.23.0-phase23" \
  --ok-count 0 --fail-count 0 --ledger "$LED" | grep -q ZERO_TESTS

echo "== PASS path atomic =="
run_expect 0 --evidence-dir "$EV" --run-all-exit 0 --auth-exit 0 \
  --artifact "$ART" --version "0.23.0-phase23" \
  --ok-count 10 --fail-count 0 --ledger "$LED" --prior-log /tmp/soviez-run-all-p23b.log
grep -q 'PASS — PHASE 23' "$EV/FINAL_REPORT.md"
grep -q "$SHA" "$EV/BUILD_ARTIFACT.md"
grep -q "$SHA" "$EV/FINAL_REPORT.md"
[[ ${#SHA} -eq 64 ]]

echo "== nonzero run refuses PASS =="
run_expect 1 --evidence-dir "$EV" --run-all-exit 1 --auth-exit 0 \
  --artifact "$ART" --version "0.23.0-phase23" \
  --ok-count 10 --fail-count 2 --ledger "$LED"
grep -q 'PARTIAL' "$EV/FINAL_REPORT.md"
! grep -q 'PASS — PHASE 23 OFFLINE UPDATE BUNDLES COMPLETE' "$EV/FINAL_REPORT.md"

echo "== malformed version empty =="
run_expect 2 --evidence-dir "$EV" --run-all-exit 0 --auth-exit 0 \
  --artifact "$ART" --version "" \
  --ok-count 1 --fail-count 0 --ledger "$LED" | grep -q VERSION_MISSING

echo "== duplicate finalization idempotent PASS =="
run_expect 0 --evidence-dir "$EV" --run-all-exit 0 --auth-exit 0 \
  --artifact "$ART" --version "0.23.0-phase23" \
  --ok-count 10 --fail-count 0 --ledger "$LED"

echo "OK test_phase23_evidence_finalizer"
rm -rf "$TMP"
exit 0
