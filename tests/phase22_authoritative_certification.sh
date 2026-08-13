#!/usr/bin/env bash
# Phase 22 authoritative certification aggregator.
# Runs soviez-sh tests/run_all.sh + SaaS G1 certification. Aggregate exit must be 0.
set -euo pipefail
SH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$SH_ROOT/docs/evidence/phase-22-source-archive-retirement"
mkdir -p "$EVID"
LOG="$EVID/AUTHORITATIVE_RUN_ALL.md"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

# shellcheck source=/dev/null
source "$SH_ROOT/tests/helpers/phase22_cert.sh"
soviez_phase22_cert_env

{
  echo "# AUTHORITATIVE_RUN_ALL"
  echo
  echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "DOCKER_HOST=$DOCKER_HOST"
  echo "SOVIEZ_PHASE22_CERTIFICATION=1"
  echo
} > "$LOG"

fail=0

echo "==> phase22_saas_certification"
set +e
bash "$SH_ROOT/scripts/phase22-saas-certification.sh" 2>&1 | tee -a /tmp/p22_auth_saas.out
rc_saas=$?
set -e
{
  echo "## SaaS certification"
  echo "exit_code: $rc_saas"
  echo
} >> "$LOG"
[[ $rc_saas -eq 0 ]] || fail=1

echo "==> tests/run_all.sh"
set +e
bash "$SH_ROOT/tests/run_all.sh" 2>&1 | tee /tmp/p22_auth_run_all.out
rc_all=$?
set -e
{
  echo "## tests/run_all.sh"
  echo "exit_code: $rc_all"
  tail -n 40 /tmp/p22_auth_run_all.out | sed 's/^/    /'
  echo
} >> "$LOG"
[[ $rc_all -eq 0 ]] || fail=1

OVERALL=PASS
AGG=0
if [[ $fail -ne 0 ]]; then
  OVERALL=FAIL
  AGG=1
fi
{
  echo "## Aggregate"
  echo "phase22_authoritative_certification: $OVERALL"
  echo "aggregate_exit_code: $AGG"
  echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$LOG"

echo "phase22_authoritative_certification=$OVERALL aggregate_exit_code=$AGG"
exit "$AGG"
