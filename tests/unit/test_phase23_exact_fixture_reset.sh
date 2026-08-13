#!/usr/bin/env bash
# Phase 23 unit — soviez_phase23_exact_fixture_reset removes ONLY exact-owned
# disposable fixtures (soviez.phase23.disposable=1 label, soviez-p23-* names,
# and stopped/dead/created soviez-stage-pg-* names). Everything else survives,
# including a still-RUNNING soviez-stage-pg-* container (must not be killed
# out from under a parallel suite).
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env

docker info >/dev/null 2>&1 || { echo "SKIP: Docker/Colima not reachable in this environment"; echo "OK test_phase23_exact_fixture_reset (skipped — no daemon)"; exit 0; }

SUFFIX="$$-$(date +%s)"
CTRL="p23reset-ctrl-unrelated-${SUFFIX}"
LABELED="p23reset-labeled-unrelated-name-${SUFFIX}"
NAMED="soviez-p23-reset-named-${SUFFIX}"
STAGE_RUNNING="soviez-stage-pg-running-${SUFFIX}"
STAGE_EXITED="soviez-stage-pg-exited-${SUFFIX}"

cleanup() {
  docker rm -f "$CTRL" "$LABELED" "$NAMED" "$STAGE_RUNNING" "$STAGE_EXITED" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== seed fixtures =="
docker run -d --name "$CTRL" alpine:3.20 sleep 300 >/dev/null
docker run -d --name "$LABELED" --label soviez.phase23.disposable=1 alpine:3.20 sleep 300 >/dev/null
docker run -d --name "$NAMED" alpine:3.20 sleep 300 >/dev/null
docker run -d --name "$STAGE_RUNNING" alpine:3.20 sleep 300 >/dev/null
docker run --name "$STAGE_EXITED" alpine:3.20 true >/dev/null

exists() { docker inspect "$1" >/dev/null 2>&1; }
running() { [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" == "true" ]]; }

exists "$CTRL" || { echo "FAIL: seed CTRL missing"; exit 1; }
exists "$LABELED" || { echo "FAIL: seed LABELED missing"; exit 1; }
exists "$NAMED" || { echo "FAIL: seed NAMED missing"; exit 1; }
running "$STAGE_RUNNING" || { echo "FAIL: seed STAGE_RUNNING not running"; exit 1; }
exists "$STAGE_EXITED" || { echo "FAIL: seed STAGE_EXITED missing"; exit 1; }

echo "== soviez_phase23_exact_fixture_reset =="
soviez_phase23_exact_fixture_reset

echo "== assertions: exact-owned removed, everything else survives =="
exists "$CTRL" || { echo "FAIL: unrelated unlabeled container was removed (over-broad reset)"; exit 1; }
echo "[assert] unrelated unlabeled container survives"

! exists "$LABELED" || { echo "FAIL: soviez.phase23.disposable=1 labeled container survived reset"; exit 1; }
echo "[assert] disposable-labeled container removed"

! exists "$NAMED" || { echo "FAIL: soviez-p23-* named container survived reset"; exit 1; }
echo "[assert] soviez-p23-* named container removed"

exists "$STAGE_RUNNING" || { echo "FAIL: RUNNING soviez-stage-pg-* container was removed (unsafe for parallel suites)"; exit 1; }
running "$STAGE_RUNNING" || { echo "FAIL: soviez-stage-pg-* running container was stopped by reset"; exit 1; }
echo "[assert] running soviez-stage-pg-* container preserved and still running"

! exists "$STAGE_EXITED" || { echo "FAIL: exited soviez-stage-pg-* container survived reset"; exit 1; }
echo "[assert] exited soviez-stage-pg-* container removed"

echo "== idempotent: second call is a no-op success =="
soviez_phase23_exact_fixture_reset

echo "OK test_phase23_exact_fixture_reset"
exit 0
