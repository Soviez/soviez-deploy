#!/usr/bin/env bash
# Phase 23 certification shared env, Docker/Postgres preflight, exact fixture reset.
# shellcheck shell=bash

soviez_phase23_cert_env() {
  export SOVIEZ_PHASE23_CERTIFICATION=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_ED25519=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_OCI_EXPORT=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_PRIVATE_REGISTRY=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_ARTIFACT_STORAGE=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_POSTGRES=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_BACKUP=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_OFFLINE_APPLY=1
  export SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY=1
  export SOVIEZ_PHASE23_REQUIRE_REAL_REBOOT=1
  export SOVIEZ_PHASE23_REQUIRE_POWERLOSS_RECOVERY=1
  export SOVIEZ_PHASE23_REQUIRE_SAAS_CHECKS=1
  export SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES=1
  export SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS=1
  export SOVIEZ_PHASE23_FORBID_REGISTRY_CREDS_IN_BUNDLE=1
  export SOVIEZ_PHASE23_FORBID_BUSINESS_DATA_IN_BUNDLE=1
  export SOVIEZ_PHASE23_SIMULATE_FULL_ENGINE=0
  export SOVIEZ_TEST_MODE=1
  export SOVIEZ_CLI_YES=1
  export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
  export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
}

soviez_phase23_assert_cert_gates() {
  [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]] || return 0
  local failures=0
  _fail() { echo "[phase23-cert] FAIL: $*" >&2; failures=$((failures + 1)); }
  if [[ "${SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES:-1}" != "1" ]]; then
    _fail "FORBID_FAKE_SIGNATURES must be 1"
  fi
  if [[ "${SOVIEZ_PHASE23_REQUIRE_REAL_ED25519:-1}" != "1" ]]; then
    _fail "REQUIRE_REAL_ED25519 must be 1"
  fi
  if [[ "${SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_PHASE23_SKIP_REBOOT:-0}" == "1" ]]; then
      _fail "reboot skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE23_SKIP_NETWORK:-0}" == "1" ]]; then
      _fail "network skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE23_SKIP_SAAS:-0}" == "1" ]]; then
      _fail "SaaS skip forbidden"
    fi
  fi
  if [[ "${SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY:-1}" == "1" && "${SOVIEZ_UPDATE_ALLOW_NETWORK:-0}" == "1" ]]; then
    _fail "network allowed during offline apply"
  fi
  if [[ "${SOVIEZ_PHASE23_SIMULATE_FULL_ENGINE:-0}" == "1" ]]; then
    _fail "SIMULATE_FULL_ENGINE forbidden in certification"
  fi
  [[ "$failures" -eq 0 ]] || return 1
  return 0
}

soviez_phase23_docker_disk_ok() {
  # Fail closed when Docker data root is critically full (<1.5GiB free).
  local avail_kb
  avail_kb="$(docker system df --format '{{.Type}} {{.Size}}' 2>/dev/null | head -1 || true)"
  # Prefer VM filesystem check via docker run
  local free_bytes
  free_bytes="$(docker run --rm --label soviez.phase23.disposable=1 alpine:3.20 \
    df -B1 / | awk 'NR==2{print $4}' 2>/dev/null || echo "")"
  if [[ -z "$free_bytes" || ! "$free_bytes" =~ ^[0-9]+$ ]]; then
    # Fallback: host-reported docker root via colima ssh if available
    if command -v colima >/dev/null 2>&1; then
      free_bytes="$(colima ssh -- df -B1 /var/lib/docker 2>/dev/null | awk 'NR==2{print $4}' || echo 0)"
    else
      free_bytes=0
    fi
  fi
  local min=$((1536 * 1024 * 1024))
  if [[ "${free_bytes:-0}" -lt "$min" ]]; then
    echo "[phase23-preflight] Docker free space too low: ${free_bytes} bytes (need >= ${min})" >&2
    return 1
  fi
  return 0
}

soviez_phase23_docker_preflight() {
  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
  if ! docker info >/dev/null 2>&1; then
    echo "[phase23-preflight] Docker daemon unreachable DOCKER_HOST=$DOCKER_HOST" >&2
    if command -v colima >/dev/null 2>&1; then
      colima status 2>&1 || true
      echo "[phase23-preflight] attempting colima start (bounded)" >&2
      colima start >/dev/null 2>&1 || true
      local i
      for i in $(seq 1 60); do
        docker info >/dev/null 2>&1 && break
        sleep 2
      done
    fi
  fi
  docker info >/dev/null 2>&1 || return 1
  soviez_phase23_docker_disk_ok || return 1
  echo "[phase23-preflight] Docker OK"
  return 0
}

soviez_phase23_postgres_preflight() {
  soviez_phase23_docker_preflight || return 1
  # Prove postgres:16 image pullability / local presence and pg_isready path.
  if ! docker image inspect postgres:16 >/dev/null 2>&1; then
    docker pull postgres:16 >/dev/null || return 1
  fi
  local name="soviez-p23-pg-preflight-$$"
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --label soviez.phase23.disposable=1 \
    -e POSTGRES_PASSWORD=preflight -e POSTGRES_USER=soviez \
    postgres:16 >/dev/null || return 1
  local i=0
  while ! docker exec "$name" pg_isready -U soviez >/dev/null 2>&1; do
    i=$((i + 1))
    [[ $i -lt 40 ]] || { docker logs "$name" 2>&1 | tail -20; docker rm -f "$name" >/dev/null; return 1; }
    sleep 0.5
  done
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "[phase23-preflight] PostgreSQL OK"
  return 0
}

soviez_phase23_exact_fixture_reset() {
  # Remove ONLY containers/volumes labeled soviez.phase23.disposable=1
  local ids
  ids="$(docker ps -aq --filter "label=soviez.phase23.disposable=1" 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    # shellcheck disable=SC2086
    docker rm -f $ids >/dev/null 2>&1 || true
  fi
  # Named exact fixtures
  local n
  for n in $(docker ps -aq --filter "name=soviez-p23-" 2>/dev/null || true); do
    docker rm -f "$n" >/dev/null 2>&1 || true
  done
  for n in $(docker ps -aq --filter "name=soviez-stage-pg-" 2>/dev/null || true); do
    # only if stopped/exited — avoid killing in-use from parallel suites unless labeled
    local st
    st="$(docker inspect -f '{{.State.Status}}' "$n" 2>/dev/null || echo missing)"
    if [[ "$st" == "exited" || "$st" == "dead" || "$st" == "created" ]]; then
      docker rm -f "$n" >/dev/null 2>&1 || true
    fi
  done
  echo "[phase23-reset] exact disposable fixtures cleared"
  return 0
}

soviez_phase23_erp_fixture_ensure() {
  # Certification ERP fixtures via release catalog (not legacy p15-* tags).
  local helper="$ROOT/tests/helpers/erp_release_fixture.sh"
  if [[ -z "${ROOT:-}" ]]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    helper="$ROOT/tests/helpers/erp_release_fixture.sh"
  fi
  # shellcheck source=/dev/null
  source "$helper"
  soviez_test_erp_fixture_tags_ensure "${SOVIEZ_TEST_CERT_RELEASE:-cert-0.24.6.4}"
}

soviez_phase23_environment_preflight_report() {
  local out="${1:-/dev/stdout}"
  {
    echo "# ENVIRONMENT_PREFLIGHT"
    echo "timestamp_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "uname: $(uname -a)"
    echo "arch: $(uname -m)"
    echo "DOCKER_HOST=${DOCKER_HOST:-}"
    docker version --format 'docker_client={{.Client.Version}} docker_server={{.Server.Version}}' 2>/dev/null || echo "docker_version: unavailable"
    docker info --format 'storage_driver={{.Driver}} cpus={{.NCPU}} mem_total={{.MemTotal}}' 2>/dev/null || true
    docker system df 2>/dev/null || true
    command -v colima >/dev/null && colima list 2>/dev/null || true
    command -v psql >/dev/null && psql --version || true
    echo "openssl: $($(command -v openssl) version 2>/dev/null || true)"
  } > "$out"
}
