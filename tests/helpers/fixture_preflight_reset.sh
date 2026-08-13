#!/usr/bin/env bash
# Exact-owned disposable fixture preflight/reset for authoritative run_all.
# Never uses docker system prune, broad volume/network deletion, or wildcard kills.
# shellcheck shell=bash

soviez_fixture_preflight_reset() {
  local docker_host="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
  export DOCKER_HOST="$docker_host"

  echo "[preflight] docker/colima health"
  if ! docker info >/dev/null 2>&1; then
    if command -v colima >/dev/null 2>&1; then
      colima start >/dev/null 2>&1 || true
      local i
      for i in $(seq 1 60); do
        docker info >/dev/null 2>&1 && break
        sleep 2
      done
    fi
  fi
  docker info >/dev/null 2>&1 || {
    echo "[preflight] FAIL: Docker/Colima unavailable" >&2
    return 1
  }

  echo "[preflight] disk/inodes"
  df -h / 2>/dev/null | tail -1 || true
  df -i / 2>/dev/null | tail -1 || true

  local net_count
  net_count="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  echo "[preflight] docker networks before=$net_count"

  # Exact-owned ephemeral networks only (timestamped restore-test / update / p19 staging).
  local n
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    echo "[preflight] rm network $n"
    docker network rm "$n" >/dev/null 2>&1 || true
  done < <(docker network ls --format '{{.Name}}' 2>/dev/null | grep -E '^(soviez-bk-rtest-net-|soviez-upd-net-|soviez-p19-stg-)' || true)

  # Exact-owned exited disposable containers (update candidates / phase18 leftovers).
  local c
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    echo "[preflight] rm container $c"
    docker rm -f "$c" >/dev/null 2>&1 || true
  done < <(docker ps -aq -f status=exited --format '{{.Names}}' 2>/dev/null | grep -E '^(soviez-upd-cand-|soviez-p19-erp-|soviez-p19-pg-|p18)' || true)

  # Stale Phase 19 freeze markers under disposable test roots only (never live customer paths).
  local root
  for root in /tmp/soviez-test.* /tmp/soviez-p19-* "${ROOT:-}/.tmp"/p19-*; do
    [[ -e "$root" ]] || continue
    find "$root" -name 'WRITE_FREEZE*' -type f 2>/dev/null | while IFS= read -r f; do
      echo "[preflight] rm freeze marker $f"
      rm -f "$f" || true
    done
  done

  net_count="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  echo "[preflight] docker networks after=$net_count"
  echo "[preflight] containers=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"

  # Phase 16 SFTP fixture readiness (exact-owned container only).
  # Recreate if not healthy so post-Colima host-key / bind races do not flake SFTP.
  if docker inspect soviez-p16-sftp >/dev/null 2>&1; then
    docker start soviez-p16-sftp >/dev/null 2>&1 || true
    local i ready=0
    for i in $(seq 1 25); do
      if nc -z 127.0.0.1 2222 2>/dev/null; then ready=1; break; fi
      sleep 1
    done
    if [[ "$ready" -ne 1 ]]; then
      echo "[preflight] recreating soviez-p16-sftp (port 2222 not ready)"
      docker rm -f soviez-p16-sftp >/dev/null 2>&1 || true
    fi
  fi
  docker network create soviez-p16-net >/dev/null 2>&1 || true

  echo "[preflight] OK"
}

soviez_fixture_midrun_network_gc() {
  # Soft GC when address-pool pressure is likely; exact-owned patterns only.
  local count
  count="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${count:-0}" -lt 20 ]]; then
    return 0
  fi
  local n
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    docker network rm "$n" >/dev/null 2>&1 || true
  done < <(docker network ls --format '{{.Name}}' 2>/dev/null | grep -E '^(soviez-bk-rtest-net-|soviez-upd-net-|soviez-p19-stg-)' || true)
}
