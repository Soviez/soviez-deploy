#!/usr/bin/env bash
# Phase 23 unit — validates the failure-classification enum used across the
# Phase 23 gap-closure evidence set. Enforces:
#   - Exactly three permitted classifications (no UNKNOWN, no free text).
#   - PRIOR_FAILURE_LEDGER.md classifies every entry using only that enum.
#   - Per-category counts match the documented root-cause accounting
#     (16 run-B failures + run-A Ed25519 cascade + evidence finalizer defect).
#   - FAILURE_CLASSIFICATION.md documents all three categories.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"

EVID="$ROOT/docs/evidence/phase-23-offline-update-bundles"
LEDGER="$EVID/PRIOR_FAILURE_LEDGER.md"
CLASSDOC="$EVID/FAILURE_CLASSIFICATION.md"

# Canonical enum — the ONLY values permitted anywhere in Phase 23 failure
# classification evidence. Deliberately excludes UNKNOWN: every observed
# failure must be attributed to a known, evidenced root-cause category.
CANONICAL=(ENVIRONMENT_FLAKE TEST_HARNESS_DEFECT EVIDENCE_FINALIZER_DEFECT)

is_canonical() {
  local v="$1" c
  for c in "${CANONICAL[@]}"; do
    [[ "$v" == "$c" ]] && return 0
  done
  return 1
}

assert_file_exists "$LEDGER"
assert_file_exists "$CLASSDOC"

echo "== enum has exactly 3 members =="
assert_eq "3" "${#CANONICAL[@]}" "canonical classification enum size"

echo "== no entry is ACTUALLY classified UNKNOWN / unclassified =="
# Deliberately narrow: the docs are allowed to *discuss* why UNKNOWN is
# forbidden in prose; what must never happen is an entry actually being
# tagged with it, or the enum defining it as a real category heading.
if grep -Eq '\*\*Classification:\*\*[[:space:]]+(UNKNOWN|UNCLASSIFIED)\b' "$LEDGER"; then
  echo "FAIL: a ledger entry is classified UNKNOWN/UNCLASSIFIED" >&2
  grep -En '\*\*Classification:\*\*[[:space:]]+(UNKNOWN|UNCLASSIFIED)\b' "$LEDGER" >&2
  exit 1
fi
if grep -Eq '^## +(UNKNOWN|UNCLASSIFIED)\b' "$CLASSDOC"; then
  echo "FAIL: $CLASSDOC defines UNKNOWN/UNCLASSIFIED as a real category" >&2
  exit 1
fi

echo "== FAILURE_CLASSIFICATION.md documents all three categories =="
for c in "${CANONICAL[@]}"; do
  grep -q "$c" "$CLASSDOC" || { echo "FAIL: $CLASSDOC missing category $c" >&2; exit 1; }
done

echo "== every ledger classification token is in the canonical enum =="
# bash 3.2 has no mapfile/readarray — build the array manually.
TOKENS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && TOKENS+=("$line")
done < <(grep -oE '\*\*Classification:\*\* [A-Z_]+' "$LEDGER" | awk '{print $NF}')
[[ "${#TOKENS[@]}" -gt 0 ]] || { echo "FAIL: no classification lines found in $LEDGER" >&2; exit 1; }
bad=0
for t in "${TOKENS[@]}"; do
  if ! is_canonical "$t"; then
    echo "FAIL: non-canonical classification token: $t" >&2
    bad=1
  fi
done
[[ "$bad" -eq 0 ]] || exit 1
echo "[assert] ${#TOKENS[@]} classification lines, all canonical"

echo "== total classified entries == 31 (prior 30 + F31 fail_count double-zero) =="
assert_eq "31" "${#TOKENS[@]}" "total classified prior-failure ledger entries"

count_of() {
  local want="$1" n=0 t
  for t in "${TOKENS[@]}"; do
    [[ "$t" == "$want" ]] && n=$((n + 1))
  done
  printf '%s\n' "$n"
}

ENV_FLAKE_COUNT="$(count_of ENVIRONMENT_FLAKE)"
HARNESS_COUNT="$(count_of TEST_HARNESS_DEFECT)"
FINALIZER_COUNT="$(count_of EVIDENCE_FINALIZER_DEFECT)"

echo "ENVIRONMENT_FLAKE=$ENV_FLAKE_COUNT TEST_HARNESS_DEFECT=$HARNESS_COUNT EVIDENCE_FINALIZER_DEFECT=$FINALIZER_COUNT"
assert_eq "20" "$ENV_FLAKE_COUNT" "ENVIRONMENT_FLAKE count"
assert_eq "10" "$HARNESS_COUNT" "TEST_HARNESS_DEFECT count"
assert_eq "1" "$FINALIZER_COUNT" "EVIDENCE_FINALIZER_DEFECT count"

echo "== ledger references its source evidence =="
grep -q 'soviez-run-all-p23b.log' "$LEDGER" || { echo "FAIL: ledger missing run-B log reference" >&2; exit 1; }
grep -q -- '--ok-count' "$ROOT/scripts/phase23_evidence_finalizer.py" || { echo "FAIL: evidence finalizer script missing expected CLI surface" >&2; exit 1; }

echo "== positive evidence required for ENVIRONMENT_FLAKE entries (no bare assertions) =="
# Every ENVIRONMENT_FLAKE row must cite a concrete log excerpt/line reference,
# not just the label — enforced by requiring an adjacent "Evidence:" field.
awk '
  /\*\*Classification:\*\* ENVIRONMENT_FLAKE/ { want=1; next }
  want && /\*\*Evidence:\*\*/ { want=0; next }
  want && /^### / { print "FAIL: ENVIRONMENT_FLAKE entry missing Evidence field before next heading"; exit 1 }
' "$LEDGER"

echo "OK test_phase23_failure_classification"
exit 0
