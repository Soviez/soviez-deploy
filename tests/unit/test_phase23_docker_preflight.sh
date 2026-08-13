#!/usr/bin/env bash
# Phase 23 unit — soviez_phase23_docker_preflight / soviez_phase23_docker_disk_ok
# Real Docker calls; bounded negative-path simulation (no real ENOSPC required).
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env

echo "== docker preflight: positive path (real daemon) =="
docker info >/dev/null 2>&1 || { echo "SKIP: Docker/Colima not reachable in this environment"; echo "OK test_phase23_docker_preflight (skipped — no daemon)"; exit 0; }
soviez_phase23_docker_preflight
echo "[assert] docker preflight OK=0"

echo "== docker disk check: positive path (real free space) =="
soviez_phase23_docker_disk_ok
echo "[assert] disk headroom OK=0"

echo "== docker disk check: forced low free-space denies (fail-closed) =="
(
  docker() {
    if [[ "$1" == "run" && "$*" == *"df -B1 /"* ]]; then
      printf 'Filesystem     1B-blocks       Used  Available Use%% Mounted on\n'
      printf 'overlay          1048576    1047552       1024  100%% /\n'
      return 0
    fi
    command docker "$@"
  }
  set +e
  soviez_phase23_docker_disk_ok
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: expected denial on <1.5GiB free"; exit 1; }
  echo "[assert] low-disk denial rc=$rc"
)

echo "== docker disk check: fallback colima ssh path when df-in-container yields no digits =="
(
  docker() {
    if [[ "$1" == "run" && "$*" == *"df -B1 /"* ]]; then
      printf 'not-a-number\n'
      return 1
    fi
    command docker "$@"
  }
  colima() {
    if [[ "$1" == "ssh" ]]; then
      printf 'Filesystem     1B-blocks       Used  Available Use%% Mounted on\n'
      printf '/dev/root      99999999999 1000000 9999999999  10%% /var/lib/docker\n'
      return 0
    fi
    command colima "$@"
  }
  soviez_phase23_docker_disk_ok
  echo "[assert] colima-ssh fallback path OK=0"
)

echo "== docker preflight: unreachable daemon + colima retries exhaust and fail closed (bounded, instant) =="
(
  sleep() { :; }
  docker() {
    if [[ "$1" == "info" ]]; then
      return 1
    fi
    command docker "$@"
  }
  colima() {
    case "$1" in
      status) return 1 ;;
      start) return 0 ;;
      *) command colima "$@" ;;
    esac
  }
  set +e
  soviez_phase23_docker_preflight
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: expected preflight failure when daemon never becomes reachable"; exit 1; }
  echo "[assert] bounded retry exhaustion rc=$rc"
)

echo "== environment preflight report is well-formed =="
REPORT="$(mktemp "${TMPDIR:-/tmp}/p23-env-report.XXXXXX")"
soviez_phase23_environment_preflight_report "$REPORT"
assert_file_exists "$REPORT"
grep -q '^# ENVIRONMENT_PREFLIGHT' "$REPORT"
grep -q '^timestamp_utc: ' "$REPORT"
grep -q '^DOCKER_HOST=' "$REPORT"
rm -f "$REPORT"

echo "OK test_phase23_docker_preflight"
exit 0
