#!/usr/bin/env bash
# Phase 23 unit — soviez_phase23_postgres_preflight (real disposable Postgres, pg_isready path).
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env

docker info >/dev/null 2>&1 || { echo "SKIP: Docker/Colima not reachable in this environment"; echo "OK test_phase23_postgres_preflight (skipped — no daemon)"; exit 0; }

echo "== postgres preflight: positive path (real disposable container) =="
# Clear any orphaned preflight containers from interrupted prior runs (exact name prefix only).
orphans="$(docker ps -aq --filter 'name=soviez-p23-pg-preflight-' 2>/dev/null || true)"
if [[ -n "$orphans" ]]; then
  # shellcheck disable=SC2086
  docker rm -f $orphans >/dev/null 2>&1 || true
fi
soviez_phase23_postgres_preflight
after_count="$(docker ps -aq --filter 'name=soviez-p23-pg-preflight-' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$after_count" "no leftover preflight container after success"
echo "[assert] after=$after_count (self-cleaning)"


echo "== postgres preflight: label + disposability =="
# Re-run and inspect labels while momentarily preventing cleanup, to prove the exact-owned label contract.
(
  _real_docker_rm_checked=0
  docker() {
    if [[ "$1" == "rm" ]]; then
      local label
      label="$(command docker inspect -f '{{ index .Config.Labels "soviez.phase23.disposable" }}' "${@: -1}" 2>/dev/null || true)"
      # Only assert when the container actually exists at removal time
      # (the function also issues a pre-emptive `rm -f` before creation).
      if [[ -n "$label" ]]; then
        _real_docker_rm_checked=1
        [[ "$label" == "1" ]] || { echo "FAIL: preflight container missing soviez.phase23.disposable=1 label (got '$label')"; exit 1; }
      fi
    fi
    command docker "$@"
  }
  soviez_phase23_postgres_preflight
  [[ "$_real_docker_rm_checked" == "1" ]] || { echo "FAIL: never observed a labeled removal — assertion did not exercise real path"; exit 1; }
  echo "[assert] disposable label verified before removal"
)

echo "== postgres preflight: docker unreachable short-circuits before container creation (bounded) =="
(
  sleep() { :; }
  docker() {
    case "$1" in
      info) return 1 ;;
      *) command docker "$@" ;;
    esac
  }
  colima() {
    case "$1" in
      status) return 1 ;;
      start) return 0 ;;
      *) command colima "$@" ;;
    esac
  }
  set +e
  soviez_phase23_postgres_preflight
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: expected failure when Docker unreachable"; exit 1; }
  echo "[assert] docker-unreachable short-circuit rc=$rc"
)

echo "== postgres preflight: pg_isready timeout cleans up container (bounded via sleep no-op) =="
(
  sleep() { :; }
  docker() {
    if [[ "$1" == "exec" ]]; then
      local a
      for a in "$@"; do
        [[ "$a" == "pg_isready" ]] && return 1
      done
    fi
    command docker "$@"
  }
  set +e
  soviez_phase23_postgres_preflight
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || { echo "FAIL: expected pg_isready timeout to fail"; exit 1; }
  echo "[assert] pg_isready timeout rc=$rc"
)
leftover="$(docker ps -aq --filter 'name=soviez-p23-pg-preflight-' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$leftover" "pg_isready-timeout path must still remove its disposable container"

echo "OK test_phase23_postgres_preflight"
exit 0
